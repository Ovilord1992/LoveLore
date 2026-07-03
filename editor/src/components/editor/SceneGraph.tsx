import { useCallback, useEffect, useMemo } from 'react';
import { ReactFlow, Background, Controls, MiniMap, type Node, type Edge, type OnConnect, type NodeChange, addEdge, useNodesState, useEdgesState } from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { useEditorStore } from '../../store/editorStore';
import './SceneGraph.css';

export function SceneGraph() {
  const { project, selectedChapterIndex, selectedSceneId, selectScene, updateScenePosition, updateScene } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];

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
            <div className="scene-node-id">{scene.id}</div>
            <div className="scene-node-info">
              {scene.events.length} событ. | {scene.charactersOnScreen.length} перс.
            </div>
            {scene.background && <div className="scene-node-bg">🖼 {scene.background}</div>}
          </div>
        ),
      },
      style: {
        background: scene.id === selectedSceneId ? '#2d1854' : '#16213e',
        border: scene.id === selectedSceneId ? '2px solid #e91e63' : '1px solid #2a2a3e',
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

  // Drag-connect: связь из графа пишем в стор (иначе она теряется).
  // Если у сцены-источника есть выбор с незаполненным nextSceneId — заполняем
  // его; иначе устанавливаем scene.nextSceneId. addEdge даёт мгновенный отклик,
  // а initialEdges пересчитается из стора и заменит рёбра — рассинхрона нет.
  const onConnect: OnConnect = useCallback((params) => {
    const { source, target } = params;
    if (chapter && source && target) {
      const sourceScene = chapter.scenes.find((s) => s.id === source);
      if (sourceScene) {
        let bound = false;
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
        } else {
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
