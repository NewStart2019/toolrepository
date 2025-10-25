// 年度总结使用
(function() {
  function fallbackCopyTextToClipboard(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";  // 避免滚动
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.opacity = "0";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    const successful = document.execCommand('copy');
    document.body.removeChild(textArea);
  }

  const copyTextToClipboard = (text) => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text);
      } else {
        fallbackCopyTextToClipboard(text);
      }
      console.log('复制到剪切板');
    } catch (err) {
      console.error('复制失败:', err);
    }
  };

  // 获取所有 .odd 行（日期标题行）
  const oddRows = Array.from(document.querySelectorAll('tr.odd'));

  if (oddRows.length === 0) {
    console.log('❌ 未找到任何日期分组 (.odd)。');
    return;
  }

  // 用户输入：要获取最近几组数据
  let input = prompt(`检测到 ${oddRows.length} 个日期分组，请输入要提取的组数：
- 输入 -1：获取全部
- 输入正整数：获取最近 N 组`, "5");

  const groupCount = parseInt(input, 10);
  if (isNaN(groupCount)) {
    console.log('❌ 输入无效，必须是数字。');
    return;
  }

  // 确定要处理的 .odd 行（取最后 N 个，即最近 N 天）
  const targetOddRows =
    groupCount === -1 ? oddRows : oddRows.slice(0,groupCount);

  if (targetOddRows.length === 0) {
    console.log('❌ 没有符合条件的日期分组。');
    return;
  }

  // 按日期分组提取工时数据
  const groupedByDate = [];

  targetOddRows.forEach(oddRow => {
    const date = oddRow.querySelector('td strong')?.textContent.trim() || '未知日期';

    // 收集该 .odd 行之后、下一个 .odd 行之前的 .time-entry
    const entries = [];
    let next = oddRow.nextElementSibling;

    while (next && !next.classList.contains('odd')) {
      if (next.classList.contains('time-entry') && next.classList.contains('hascontextmenu')) {
        const subject = next.querySelector('td.subject')?.textContent.trim();
        const activity = next.querySelector('td.activity')?.textContent.trim().replace(/\s+/g, ' ');
        const comments = next.querySelector('td.comments')?.textContent.trim() || '';
        const hoursInt = next.querySelector('td.hours .hours-int')?.textContent.trim() || '0';
        const hoursDec = next.querySelector('td.hours .hours-dec')?.textContent.trim().replace(':', '') || '00';
        const hoursFormatted = `${hoursInt}:${hoursDec}`;

        entries.push({
          subject,
          activity,
          comments,
          hoursFormatted
        });
      }
      next = next.nextElementSibling;
    }

    groupedByDate.push({ date, entries });
  });

  // 扁平化所有工时条目，用于后续按 subject 分类
  const allEntries = groupedByDate.flatMap(day =>
    day.entries.map(e => ({ ...e, date: day.date }))
  );

  // 按 subject 分类
  const bySubject = allEntries.reduce((acc, item) => {
    if (!acc[item.subject]) acc[item.subject] = [];
    acc[item.subject].push(item);
    return acc;
  }, {});

  // 生成 Markdown
  let markdown = `## 工时统计（共 ${allEntries.length} 条 | 最近 ${targetOddRows.length} 天）\n\n`;

  for (const [subject, items] of Object.entries(bySubject)) {
    markdown += `### ${subject}\n\n`;
    markdown += '| 序号 | 日期       | 活动     | 注释             | 工时 |\n';
    markdown += '|------|------------|----------|------------------|------|\n';

    items.forEach((item, index) => {
      markdown += `| ${index + 1} | ${item.date} | ${item.activity} | ${item.comments} | ${item.hoursFormatted} |\n`;
    });

    markdown += '\n';
  }

  // 输出到控制台
  console.log('%c✅ Markdown 已生成，可复制以下内容：', 'font-weight:bold;color:green;');
  console.log(markdown);

  // 尝试复制到剪贴板
  copyTextToClipboard(markdown);
  return { groupedByDate, bySubject, markdown };
})();

// 周报 汇总使用
(function() {
  function fallbackCopyTextToClipboard(text) {
    const textArea = document.createElement("textarea");
    textArea.value = text;
    textArea.style.position = "fixed";  // 避免滚动
    textArea.style.top = "0";
    textArea.style.left = "0";
    textArea.style.opacity = "0";
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();
    const successful = document.execCommand('copy');
    document.body.removeChild(textArea);
  }

  const copyTextToClipboard = (text) => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text);
      } else {
        fallbackCopyTextToClipboard(text);
      }
      console.log('复制到剪切板');
    } catch (err) {
      console.error('复制失败:', err);
    }
  };

  // 获取所有 .odd 行（日期标题行）
  const oddRows = Array.from(document.querySelectorAll('tr.odd'));

  if (oddRows.length === 0) {
    console.log('❌ 未找到任何日期分组 (.odd)。');
    return;
  }

  // 用户输入：要获取最近几组数据
  let input = prompt(`检测到 ${oddRows.length} 个日期分组，请输入要提取的组数：
- 输入 -1：获取全部
- 输入正整数：获取最近 N 组`, "5");

  const groupCount = parseInt(input, 10);
  if (isNaN(groupCount)) {
    console.log('❌ 输入无效，必须是数字。');
    return;
  }

  // 确定要处理的 .odd 行（取最后 N 个，即最近 N 天）
  const targetOddRows =
    groupCount === -1 ? oddRows : oddRows.slice(0,groupCount);

  if (targetOddRows.length === 0) {
    console.log('❌ 没有符合条件的日期分组。');
    return;
  }

  // 按日期分组提取工时数据
  const groupedByDate = [];

  targetOddRows.forEach(oddRow => {
    const date = oddRow.querySelector('td strong')?.textContent.trim() || '未知日期';

    // 收集该 .odd 行之后、下一个 .odd 行之前的 .time-entry
    const entries = [];
    let next = oddRow.nextElementSibling;

    while (next && !next.classList.contains('odd')) {
      if (next.classList.contains('time-entry') && next.classList.contains('hascontextmenu')) {
        const subject = next.querySelector('td.subject')?.textContent.trim();
        const activity = next.querySelector('td.activity')?.textContent.trim().replace(/\s+/g, ' ');
        const comments = next.querySelector('td.comments')?.textContent.trim() || '';
        const hoursInt = next.querySelector('td.hours .hours-int')?.textContent.trim() || '0';
        const hoursDec = next.querySelector('td.hours .hours-dec')?.textContent.trim().replace(':', '') || '00';
        const hoursFormatted = `${hoursInt}:${hoursDec}`;

        entries.push({
          subject,
          activity,
          comments,
          hoursFormatted
        });
      }
      next = next.nextElementSibling;
    }

    groupedByDate.push({ date, entries });
  });

  // 扁平化所有工时条目，用于后续按 subject 分类
  const allEntries = groupedByDate.flatMap(day =>
    day.entries.map(e => ({ ...e, date: day.date }))
  );

  // 按 subject 分类
  const bySubject = allEntries.reduce((acc, item) => {
    if (!acc[item.subject]) acc[item.subject] = [];
    acc[item.subject].push(item);
    return acc;
  }, {});

  // 生成 Markdown
  let markdown = `## 工时统计（共 ${allEntries.length} 条 | 最近 ${targetOddRows.length} 天）\n\n`;

  for (const [subject, items] of Object.entries(bySubject)) {
    markdown += `### ${subject}\n\n`;
    items.forEach((item, index) => {
      markdown += `${index + 1}. ${item.comments} \n`
    });

    markdown += '\n';
  }

  // 输出到控制台
  console.log('%c✅ Markdown 已生成，可复制以下内容：', 'font-weight:bold;color:green;');
  console.log(markdown);

  // 尝试复制到剪贴板
  copyTextToClipboard(markdown);
  return { groupedByDate, bySubject, markdown };
})();