let data = '';
process.stdin.on('data', (c) => (data += c));
process.stdin.on('end', () => {
  try {
    const j = JSON.parse(data);
    const f = j.tool_input?.file_path ?? j.tool_response?.filePath ?? '';
    process.stdout.write(f);
  } catch {
    process.stdout.write('');
  }
});
