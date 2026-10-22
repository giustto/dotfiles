"""Return a pytest node selector for the test containing the supplied line."""
import ast
import json
import sys
from pathlib import Path

tree = ast.parse(Path(sys.argv[1]).read_text())
line = int(sys.argv[2])


def find(node, parents):
    for child in ast.iter_child_nodes(node):
        if isinstance(child, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            start = min([child.lineno] + [d.lineno for d in child.decorator_list])
            if start <= line <= child.end_lineno:
                if isinstance(child, ast.ClassDef):
                    return find(child, parents + [child.name])
                if child.name.startswith("test_"):
                    return "::".join(parents + [child.name])
        found = find(child, parents)
        if found:
            return found


print(json.dumps({"selector": find(tree, [])}))
