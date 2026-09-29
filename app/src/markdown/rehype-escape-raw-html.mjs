function visitChildren(node) {
  if (!Array.isArray(node.children)) return;
  node.children = node.children.map((child) => {
    if (child.type === 'raw') {
      return {
        type: 'element',
        tagName: 'code',
        properties: { className: ['raw-html-example'] },
        children: [{ type: 'text', value: child.value }]
      };
    }
    visitChildren(child);
    return child;
  });
}

export function rehypeEscapeRawHtml() {
  return (tree) => visitChildren(tree);
}
