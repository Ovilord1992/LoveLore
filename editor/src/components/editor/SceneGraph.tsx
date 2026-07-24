import { useCallback, useEffect, useMemo, useRef } from 'react';
import { ReactFlow, Background, Controls, MiniMap, type Node, type Edge, type OnConnect, type NodeChange, type ReactFlowInstance, addEdge, useNodesState, useEdgesState } from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { useEditorStore } from '../../store/editorStore';
import { conditionSummary } from '../../utils/conditions';
import './SceneGraph.css';

export function SceneGraph() {
  const { project, selectedChapterIndex, selectedSceneId, selectScene, updateScenePosition, updateScene } = useEditorStore();
  const focusSceneRequest = useEditorStore((s) => s.focusSceneRequest);
  const chapter = project.chapters[selectedChapterIndex];
  const instanceRef = useRef<ReactFlowInstance | null>(null);
  const handledFocusNonce = useRef<number>(0);

  // ВАЖНО: все хуки вызываются безусловно ДО любого раннего return (rules-of-hooks).
  const { initialNodes, initialEdges } = useMemo(() => {
    if (!chapter) return { initialNodes: [] as Node[], initialEdges: [] as Edge[] };
    const nodes: Node[] = chapter.scenes.map((scene, i) => ({
      id: scene.id,
      // Если у сцены сохранена позиция — используем её; иначе авто-раскладка.
      position: scene.editorPosition
        ? { x: scene.editorPosition.x, y: scene.editorPosition.y }
        : { x: (i % 4) * 250, y: Math.floor(i / 4) * 180 },
      data: {
        label: (
          <div className="scene-node-content">
            <div className="scene-node-id">
              {scene.id}
              {scene.ending && (
                <span className="scene-node-ending-badge" title={`Концовка: ${scene.ending.title || scene.ending.id}`}>🏁</span>
              )}
            </div>
            <div className="scene-node-info">
              {scene.events.length} событ. | {scene.charactersOnScreen.length} перс.
              {(scene.branches?.length || 0) > 0 && ` | ⑃ ${scene.branches!.length}`}
            </div>
            {scene.background && <div className="scene-node-bg">🖼 {scene.background}</div>}
          </div>
        ),
      },
      style: {
        background: scene.id === selectedSceneId ? '#2d1854' : '#16213e',
        border: scene.id === selectedSceneId
          ? '2px solid #e91e63'
          : scene.ending ? '1px solid #b8860b' : '1px solid #2a2a3e',
        borderRadius: '10px',
        color: '#fff',
        padding: '8px',
        minWidth: '160px',
      },
    }));

    const edges: Edge[] = [];
    for (const scene of chapter.scenes) {
      // nextSceneId
      if (scene.nextSceneId) {
        edges.push({
          id: `${scene.id}->${scene.nextSceneId}`,
          source: scene.id,
          target: scene.nextSceneId,
          animated: true,
          style: { stroke: '#666' },
        });
      }
      // Ветки (v2 1.2): пунктирные рёбра с подписью условия
      (scene.branches || []).forEach((branch, bi) => {
        if (!branch.nextSceneId) return;
        edges.push({
          id: `branch:${scene.id}:${bi}->${branch.nextSceneId}`,
          source: scene.id,
          target: branch.nextSceneId,
          label: `ветка ${bi + 1}: ${conditionSummary(branch.conditions, branch.conditionsLogic)}`.slice(0, 40),
          style: { stroke: '#00bcd4', strokeDasharray: '6 3' },
          labelStyle: { fill: '#00bcd4', fontSize: 10 },
          labelBgStyle: { fill: '#0f0f1e', fillOpacity: 0.7 },
        });
      });
      // Выборы
      for (const event of scene.events) {
        if (event.type === 'choice' && event.choices) {
          for (const choice of event.choices) {
            if (choice.nextSceneId) {
              edges.push({
                id: `${scene.id}->${choice.nextSceneId}:${choice.text}`,
                source: scene.id,
                target: choice.nextSceneId,
                label: choice.text.slice(0, 20),
                style: { stroke: choice.premium ? '#9c27b0' : '#e91e63' },
                labelStyle: { fill: '#999', fontSize: 10 },
              });
            }
          }
        }
      }
    }

    return { initialNodes: nodes, initialEdges: edges };
  }, [chapter, selectedSceneId]);

  const [nodes, setNodes, onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);

  useEffect(() => { setNodes(initialNodes); }, [initialNodes, setNodes]);
  useEffect(() => { setEdges(initialEdges); }, [initialEdges, setEdges]);

  // Центрирование по запросу (клик по ошибке валидации / результату поиска).
  useEffect(() => {
    if (!focusSceneRequest || focusSceneRequest.nonce === handledFocusNonce.current) return;
    const inst = instanceRef.current;
    if (!inst) return;
    const node = nodes.find((n) => n.id === focusSceneRequest.sceneId);
    if (!node) return;
    handledFocusNonce.current = focusSceneRequest.nonce;
    const w = node.measured?.width ?? 180;
    const h = node.measured?.height ?? 80;
    void inst.setCenter(node.position.x + w / 2, node.position.y + h / 2, { zoom: 1.1, duration: 400 });
  }, [focusSceneRequest, nodes]);

  // Drag-connect: связь из графа пишем в стор (иначе она теряется).
  // Приоритет: незаполненная ветка → незаполненный вариант выбора →
  // scene.nextSceneId. addEdge даёт мгновенный отклик, а initialEdges
  // пересчитается из стора и заменит рёбра — рассинхрона нет.
  const onConnect: OnConnect = useCallback((params) => {
    const { source, target } = params;
    if (chapter && source && target) {
      const sourceScene = chapter.scenes.find((s) => s.id === source);
      if (sourceScene) {
        let bound = false;
        // 1) ветка без цели
        const emptyBranchIdx = (sourceScene.branches || []).findIndex((b) => !b.nextSceneId);
        if (emptyBranchIdx !== -1) {
          const branches = sourceScene.branches!.map((b, i) => i === emptyBranchIdx ? { ...b, nextSceneId: target } : b);
          updateScene(source, { branches });
          bound = true;
        }
        // 2) вариант выбора без цели
        if (!bound) {
          const events = sourceScene.events.map((ev) => {
            if (bound || ev.type !== 'choice' || !ev.choices || ev.choices.length === 0) return ev;
            const idx = ev.choices.findIndex((c) => !c.nextSceneId);
            if (idx === -1) return ev;
            bound = true;
            const choices = ev.choices.map((c, i) => i === idx ? { ...c, nextSceneId: target } : c);
            return { ...ev, choices };
          });
          if (bound) {
            updateScene(source, { events });
          }
        }
        // 3) обычный переход
        if (!bound) {
          updateScene(source, { nextSceneId: target });
        }
      }
    }
    setEdges((eds) => addEdge(params, eds));
  }, [chapter, updateScene, setEdges]);

  // Удаление ребра (Backspace/Delete): вычищаем соответствующую ссылку в сторе.
  const onEdgesDelete = useCallback((deleted: Edge[]) => {
    if (!chapter) return;
    for (const edge of deleted) {
      const src = chapter.scenes.find((s) => s.id === edge.source);
      if (!src) continue;
      // Ребро ветки: id вида `branch:${source}:${index}->${target}`.
      if (edge.id.startsWith('branch:')) {
        const m = edge.id.match(/^branch:(.+):(\d+)->/);
        if (m) {
          const bi = parseInt(m[2], 10);
          if (src.branches && src.branches[bi]?.nextSceneId === edge.target) {
            const branches = src.branches.map((b, i) => i === bi ? { ...b, nextSceneId: '' } : b);
            updateScene(edge.source, { branches });
          }
        }
        continue;
      }
      // Ребро nextSceneId имеет id вида `${source}->${target}` (без суффикса).
      if (edge.id === `${edge.source}->${edge.target}` && src.nextSceneId === edge.target) {
        updateScene(edge.source, { nextSceneId: undefined });
        continue;
      }
      // Иначе — ребро выбора: очищаем первый вариант, ведущий к target.
      let cleared = false;
      const events = src.events.map((ev) => {
        if (cleared || ev.type !== 'choice' || !ev.choices) return ev;
        const idx = ev.choices.findIndex((c) => c.nextSceneId === edge.target);
        if (idx === -1) return ev;
        cleared = true;
        const choices = ev.choices.map((c, i) => i === idx ? { ...c, nextSceneId: '' } : c);
        return { ...ev, choices };
      });
      if (cleared) updateScene(edge.source, { events });
    }
  }, [chapter, updateScene]);

  // Обёртка над onNodesChange из useNodesState: после завершения drag
  // (change.dragging === false) сохраняем позицию в стор, чтобы она
  // переживала переключение глав и перезагрузку.
  const handleNodesChange = useCallback((changes: NodeChange[]) => {
    onNodesChange(changes);
    if (!chapter) return;
    for (const change of changes) {
      if (change.type === 'position' && change.dragging === false && change.position) {
        updateScenePosition(chapter.id, change.id, {
          x: change.position.x,
          y: change.position.y,
        });
      }
    }
  }, [onNodesChange, updateScenePosition, chapter]);

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    selectScene(node.id);
  }, [selectScene]);

  if (!chapter) return <div className="scene-graph empty">Нет глав</div>;

  return (
    <div className="scene-graph">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onInit={(inst) => { instanceRef.current = inst; }}
        onNodesChange={handleNodesChange}
        onEdgesChange={onEdgesChange}
        onEdgesDelete={onEdgesDelete}
        onConnect={onConnect}
        onNodeClick={onNodeClick}
        fitView
        colorMode="dark"
      >
        <Background gap={20} size={1} color="#1a1a2e" />
        <Controls />
        <MiniMap
          nodeColor={(n) => n.id === selectedSceneId ? '#e91e63' : '#16213e'}
          maskColor="rgba(0,0,0,0.7)"
        />
      </ReactFlow>
    </div>
  );
}
