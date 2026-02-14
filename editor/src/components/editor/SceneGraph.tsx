import { useCallback, useMemo } from 'react';
import { ReactFlow, Background, Controls, MiniMap, type Node, type Edge, type OnConnect, addEdge, useNodesState, useEdgesState } from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { useEditorStore } from '../../store/editorStore';
import './SceneGraph.css';

export function SceneGraph() {
  const { project, selectedChapterIndex, selectedSceneId, selectScene } = useEditorStore();
  const chapter = project.chapters[selectedChapterIndex];
  if (!chapter) return <div className="scene-graph empty">Нет глав</div>;

  const { initialNodes, initialEdges } = useMemo(() => {
    const nodes: Node[] = chapter.scenes.map((scene, i) => ({
      id: scene.id,
      position: { x: (i % 4) * 250, y: Math.floor(i / 4) * 180 },
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

  const [nodes, , onNodesChange] = useNodesState(initialNodes);
  const [edges, setEdges, onEdgesChange] = useEdgesState(initialEdges);

  const onConnect: OnConnect = useCallback(
    (params) => setEdges((eds) => addEdge(params, eds)),
    [setEdges]
  );

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    selectScene(node.id);
  }, [selectScene]);

  return (
    <div className="scene-graph">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
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
