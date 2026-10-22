// Use the installed TypeScript compiler to recognize nested Jest/Vitest tests.
const fs = require('fs');
const path = require('path');
const ts = require(process.argv[4]);
const filename = process.argv[2];
const source = ts.createSourceFile(filename, fs.readFileSync(filename, 'utf8'), ts.ScriptTarget.Latest, true,
  filename.endsWith('x') ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
const line = Number(process.argv[3]) - 1;
let result, parts;
function visit(node, suites) {
  let next = suites;
  if (ts.isCallExpression(node)) {
    const callee = node.expression.getText(source);
    const start = source.getLineAndCharacterOfPosition(node.getStart(source)).line;
    const end = source.getLineAndCharacterOfPosition(node.getEnd()).line;
    if (start <= line && line <= end && /^(describe|suite|test|it)(\.|$)/.test(callee)) {
      const title = node.arguments[0];
      // Generated/parameterized names need runtime collection; run the file instead.
      if (title && (ts.isStringLiteral(title) || ts.isNoSubstitutionTemplateLiteral(title)) &&
          !callee.includes('each') && !/[%$]/.test(title.text)) {
        next = suites.concat(title.text);
        if (/^(test|it)(\.|$)/.test(callee)) { result = next.join(' '); parts = next; }
      }
    }
  }
  ts.forEachChild(node, child => visit(child, next));
}
visit(source, []);
process.stdout.write(JSON.stringify({selector: result || null, parts}));
