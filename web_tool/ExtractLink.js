(async () => {
  // 1. 提取所有有效的字体链接
  const rawLinks = [...document.querySelectorAll('a[href]')]
    .map(a => a.href.trim())
    .filter(href => {
      try { new URL(href); return true; } catch { return false; }
    })
    .filter(href => /\.(ttf|otf|woff2?|ttc|eot)(\?|#|$)/i.test(href));

  if (rawLinks.length === 0) {
    alert('没找到字体文件链接');
    return;
  }

  // 2. 生成 { lowerFilename: originalUrl } 映射，并自动去重（保留最先出现的）
  const seen = new Map(); // key: 小写文件名  value: 原始完整URL

  rawLinks.forEach(url => {
    const pathname = new URL(url).pathname;
    let filename = decodeURIComponent(pathname.split('/').pop().split('?')[0].split('#')[0]);
    const lowerFilename = filename.toLowerCase();

    // 如果还没见过这个小写文件名，就记录下来（实现去重）
    if (!seen.has(lowerFilename)) {
      seen.set(lowerFilename, url);
    }
  });

  // 3. 生成最终命令
  const commands = [];
  for (const [lowerFilename, url] of seen) {
    commands.push(` curl -o "/usr/share/fonts/${lowerFilename}" ${url} && \\`);
  }

  const resultText = commands.join('\n');

  // 4. 复制到剪贴板并提示
  await copy(resultText);
  console.log(`已去重，共 ${seen.size} 个唯一字体文件：\n\n${resultText}`);
  alert(`成功！已去重并复制 ${seen.size} 条 curl 命令到剪贴板\n（文件名重复的只保留第一个）`);
})();