/// Manual extractor for Zhengfang-style timetable pages.
///
/// The user starts extraction explicitly. The script never clicks controls or
/// changes page location. On a new Zhengfang page it first reads the official
/// same-origin timetable JSON response; otherwise it falls back to a
/// rowspan/colspan-aware DOM matrix parser.
const wzuAssistantScript = r'''
(async () => {
  if (!window.WzuSync || !document.body) return;
  const send = (payload) => WzuSync.postMessage(JSON.stringify(payload));
  const clean = (value) => String(value || '')
    .replace(/\u00a0/g, ' ')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .trim();
  const intValue = (value) => {
    const match = clean(value).match(/\d+/);
    return match ? Number(match[0]) : null;
  };
  const weekdayFromText = (value) => {
    const match = clean(value).match(/(?:星期|周)([一二三四五六日天])/);
    return match ? ({一:1, 二:2, 三:3, 四:4, 五:5, 六:6, 日:7, 天:7})[match[1]] : null;
  };
  const sectionsFromText = (value) => {
    const text = clean(value);
    let match = text.match(/(?:第)?\s*(\d{1,2})\s*[-~至—–]\s*(\d{1,2})\s*节?/);
    if (match) return [Number(match[1]), Number(match[2])];
    match = text.match(/(?:第)?\s*(\d{1,2})\s*节/);
    return match ? [Number(match[1]), Number(match[1])] : null;
  };
  const field = (text, labels) => {
    for (const label of labels) {
      const match = clean(text).match(new RegExp(label + '\\s*[:：]?\\s*([^\\n]+)'));
      if (match) return clean(match[1]);
    }
    return '';
  };
  const attr = (node, names) => {
    for (const name of names) {
      if (!node) continue;
      const kebab = name.replace(/[A-Z]/g, c => '-' + c.toLowerCase());
      for (const candidate of [name, kebab, 'data-' + kebab]) {
        const value = node.getAttribute && node.getAttribute(candidate);
        if (value !== null && clean(value) !== '') return clean(value);
      }
      if (node.dataset && node.dataset[name] !== undefined) return clean(node.dataset[name]);
    }
    return '';
  };
  const apiField = (object, names) => {
    if (!object || typeof object !== 'object') return '';
    const keys = Object.keys(object);
    for (const name of names) {
      const key = keys.find(value => value.toLowerCase() === name.toLowerCase());
      if (!key) continue;
      const value = object[key];
      if (value !== null && value !== undefined && typeof value !== 'object' && clean(value)) {
        return clean(value);
      }
    }
    return '';
  };
  const titledField = (node, labels) => {
    if (!node || !node.querySelectorAll) return '';
    for (const element of node.querySelectorAll('[title], [data-original-title], [aria-label]')) {
      const hint = clean(element.getAttribute('title') ||
        element.getAttribute('data-original-title') || element.getAttribute('aria-label'));
      if (!labels.some(label => hint.includes(label))) continue;
      const own = clean(element.textContent);
      if (own && !labels.some(label => own === label)) return own;
      let value = '';
      for (let sibling = element.nextSibling; sibling; sibling = sibling.nextSibling) {
        if (sibling.nodeName === 'BR') break;
        value += ' ' + clean(sibling.textContent);
      }
      if (clean(value)) return clean(value);
    }
    return '';
  };
  const paragraphField = (node, labels, fallbackIndex) => {
    if (!node || !node.querySelectorAll) return '';
    const paragraphs = [...node.querySelectorAll(':scope > p, :scope > div > p')];
    for (const paragraph of paragraphs) {
      const raw = clean(paragraph.textContent);
      for (const label of labels) {
        const match = raw.match(new RegExp(label + '\\s*[:：]?\\s*(.+)'));
        if (match && clean(match[1])) return clean(match[1]);
      }
    }
    // WZU's grid view hides the labels with CSS. innerText therefore contains
    // only the value: p[0]=section/week, p[1]=location, p[2]=teacher.
    if (node.matches && node.matches('.timetable_con') && paragraphs[fallbackIndex]) {
      const paragraph = paragraphs[fallbackIndex];
      const visibleValues = [...paragraph.querySelectorAll('font, span')]
        .filter(element => !element.matches('.hidden, [hidden], [aria-hidden="true"]'))
        .map(element => clean(element.innerText || element.textContent))
        .filter(value => value && !labels.some(label => value === label || value === label + '：'));
      if (visibleValues.length) return visibleValues[visibleValues.length - 1];
      let value = clean(paragraph.innerText || paragraph.textContent);
      for (const label of labels) {
        value = value.replace(new RegExp('^' + label + '\\s*[:：]?\\s*'), '');
      }
      return clean(value);
    }
    return '';
  };
  const normalizeApiItem = (course) => {
    const sectionsText = apiField(course, ['jcs', 'jc', 'jcsText']);
    const sections = sectionsFromText(sectionsText);
    const day = intValue(apiField(course, ['xqj', 'weekday', 'day']));
    const name = apiField(course, ['kcmc', 'courseName']);
    if (!name || !(day >= 1 && day <= 7) || !sections) return null;
    return {
      name,
      text: '',
      day,
      startSection: sections[0],
      sectionCount: sections[1] - sections[0] + 1,
      sectionsText,
      weeksText: apiField(course, ['zcd', 'weeks', 'weekText']),
      teacher: apiField(course, ['xm', 'jsxm', 'teacher', 'rkjs']),
      location: apiField(course, [
        'cdmc', 'jxdd', 'jxcdmc', 'cd', 'classroom', 'roomName', 'skdd', 'jsmc'
      ]),
      confidence: 'api'
    };
  };
  const findCourseList = (value, depth = 0) => {
    if (depth > 5 || !value || typeof value !== 'object') return null;
    if (Array.isArray(value)) {
      if (value.some(item => item && typeof item === 'object' &&
          (apiField(item, ['kcmc', 'courseName']) || apiField(item, ['xqj', 'weekday'])))) {
        return value;
      }
      for (const item of value) {
        const nested = findCourseList(item, depth + 1);
        if (nested) return nested;
      }
      return null;
    }
    for (const key of ['kbList', 'items', 'rows', 'data']) {
      if (!(key in value)) continue;
      const nested = findCourseList(value[key], depth + 1);
      if (nested) return nested;
    }
    for (const nestedValue of Object.values(value)) {
      const nested = findCourseList(nestedValue, depth + 1);
      if (nested) return nested;
    }
    return null;
  };

  let apiItems = [];

  // New Zhengfang (jwglxt): read the same-origin structured timetable data.
  try {
    if (location.href.includes('jwglxt')) {
      const xnm = document.querySelector('#xnm')?.value || '';
      const xqm = document.querySelector('#xqm')?.value || '';
      const marker = location.pathname.indexOf('/kbcx/');
      const root = marker >= 0
        ? location.pathname.substring(0, marker)
        : (location.pathname.includes('/jwglxt/')
            ? location.pathname.substring(0, location.pathname.indexOf('/jwglxt/') + 8)
            : '/jwglxt');
      const query = new URLSearchParams(location.search);
      const gnmkdm = query.get('gnmkdm') || 'N253508';
      const endpoint = root.replace(/\/$/, '') +
        '/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=' + encodeURIComponent(gnmkdm);
      const params = new URLSearchParams();
      if (xnm) params.set('xnm', xnm);
      if (xqm) params.set('xqm', xqm);
      params.set('kzlx', 'ck');
      params.set('xsdm', '');
      params.set('kclbdm', '');
      params.set('kclxdm', '');
      const response = await fetch(endpoint, {
        method: 'POST',
        credentials: 'include',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
        },
        body: params.toString()
      });
      if (response.ok) {
        const payload = await response.json();
        const list = findCourseList(payload) || [];
        apiItems = list.map(normalizeApiItem).filter(Boolean);
      }
    }
  } catch (_) {
    // Some deployments disable this endpoint; continue with DOM parsing.
  }

  const items = [];
  const detailHints = [];
  const fingerprints = new Set();
  const pushItem = (item) => {
    if (!item || !item.name || !(item.day >= 1 && item.day <= 7) ||
        !(item.startSection >= 1 && item.startSection <= 13)) return;
    item.sectionCount = Math.max(1, Math.min(Number(item.sectionCount) || 1, 14 - item.startSection));
    const key = [item.name, item.day, item.startSection, item.sectionCount,
      item.weeksText, item.teacher, item.location].join('|');
    if (fingerprints.has(key)) return;
    fingerprints.add(key);
    items.push(item);
  };

  for (const table of [...document.querySelectorAll('table')]) {
    const rows = [...table.querySelectorAll('tr')];
    if (!rows.length) continue;
    const grid = [];
    const origins = new Map();
    for (let r = 0; r < rows.length; r++) {
      grid[r] ||= [];
      let c = 0;
      for (const cell of [...rows[r].querySelectorAll(':scope > th, :scope > td')]) {
        while (grid[r][c] !== undefined) c++;
        const rowSpan = Math.max(1, Number(cell.rowSpan) || 1);
        const colSpan = Math.max(1, Number(cell.colSpan) || 1);
        origins.set(cell, {row: r, col: c, rowSpan, colSpan});
        for (let rr = 0; rr < rowSpan; rr++) {
          grid[r + rr] ||= [];
          for (let cc = 0; cc < colSpan; cc++) grid[r + rr][c + cc] = cell;
        }
        c += colSpan;
      }
    }

    const columnDays = new Map();
    for (let r = 0; r < Math.min(5, grid.length); r++) {
      for (let c = 0; c < grid[r].length; c++) {
        const day = weekdayFromText(grid[r][c]?.innerText);
        if (day) columnDays.set(c, day);
      }
    }
    const rowSections = new Map();
    for (let r = 0; r < grid.length; r++) {
      for (let c = 0; c < Math.min(3, grid[r].length); c++) {
        const text = clean(grid[r][c]?.innerText);
        const exact = text.match(/^(?:第)?\s*(\d{1,2})\s*节?$/);
        if (exact) {
          const section = Number(exact[1]);
          if (section >= 1 && section <= 13) rowSections.set(r, section);
        }
      }
    }

    for (const [cell, pos] of origins.entries()) {
      const blocks = [...cell.querySelectorAll(
        '.timetable_con, .kbcontent, .course, .kb-item, [data-kcmc], [data-course-name]'
      )];
      const nodes = blocks.length ? blocks : [cell];
      for (const node of nodes) {
        const text = clean(node.innerText || node.textContent);
        if (text.length < 2) continue;
        const lines = text.split(/\n+/).map(clean).filter(Boolean);
        const titleNode = node.querySelector && node.querySelector(
          '.title, .course-name, .kcmc, [data-kcmc], strong, b'
        );
        const name = clean(
          attr(node, ['kcmc', 'courseName']) ||
          (titleNode && titleNode.textContent) ||
          lines.find(line => !/(周次|上课周|星期|第\s*\d+\s*节|教师|老师|主讲|教室|地点|校区)/.test(line)) || ''
        );
        if (!name || name.length > 80 || weekdayFromText(name)) continue;

        let day = intValue(attr(node, ['xqj', 'weekday', 'day', 'xq']));
        if (!(day >= 1 && day <= 7)) day = weekdayFromText(text);
        if (!(day >= 1 && day <= 7)) {
          for (let c = pos.col; c < pos.col + pos.colSpan; c++) {
            if (columnDays.has(c)) { day = columnDays.get(c); break; }
          }
        }

        let sections = sectionsFromText(attr(node, ['jcs', 'sections', 'jc']) || text);
        let start = intValue(attr(node, ['qsjs', 'startSection']));
        let count = intValue(attr(node, ['skcd', 'sectionCount']));
        if (!start && sections) start = sections[0];
        if (!count && sections) count = sections[1] - sections[0] + 1;
        if (!start) start = rowSections.get(pos.row);
        if (!count && start) {
          const covered = [];
          for (let r = pos.row; r < pos.row + pos.rowSpan; r++) {
            if (rowSections.has(r)) covered.push(rowSections.get(r));
          }
          count = covered.length > 1 ? Math.max(...covered) - Math.min(...covered) + 1 : pos.rowSpan;
        }

        const weeksText = clean(
          attr(node, ['zcd', 'weeks', 'weekText']) ||
          (text.match(/\d+(?:\s*[-~至—–]\s*\d+)?\s*周(?:\s*[（(][单双]周?[）)])?/) || [])[0] || ''
        );
        const teacher = clean(attr(node, ['xm', 'teacher', 'jsxm']) ||
          titledField(node, ['教师', '老师', '主讲']) ||
          paragraphField(node, ['教师', '老师', '主讲'], 2) ||
          field(text, ['教师', '老师', '主讲']));
        const courseLocation = clean(
          attr(node, ['cdmc', 'jxdd', 'jxcdmc', 'jxcd', 'classroomName', 'location', 'room']) ||
          titledField(node, ['上课地点', '地点', '教室', '场地']) ||
          paragraphField(node, ['上课地点', '地点', '教室', '场地'], 1) ||
          field(text, ['上课地点', '地点', '教室', '场地'])
        );
        if (teacher || courseLocation) {
          detailHints.push({name, day, startSection: start, teacher, location: courseLocation});
        }
        pushItem({
          name,
          text,
          day,
          startSection: start,
          sectionCount: count,
          weeksText,
          teacher,
          location: courseLocation,
          confidence: 'dom-matrix'
        });
      }
    }
  }

  if (apiItems.length) {
    const enriched = apiItems.map(item => {
      const candidates = [...items, ...detailHints].filter(other =>
        clean(other.name) === clean(item.name) &&
        (!(other.day >= 1) || other.day === item.day) &&
        (!(other.startSection >= 1) || other.startSection === item.startSection));
      const hint = candidates.find(other => other.location) || candidates[0];
      return {
        ...item,
        teacher: item.teacher || (hint && hint.teacher) || '',
        location: item.location || (hint && hint.location) || ''
      };
    });
    for (const item of items) {
      const exists = enriched.some(other => clean(other.name) === clean(item.name) &&
        other.day === item.day && other.startSection === item.startSection &&
        other.sectionCount === item.sectionCount);
      if (!exists) enriched.push(item);
    }
    send({type: 'courses', items: enriched, method: 'zhengfang-api+dom'});
  } else if (items.length) {
    send({type: 'courses', items, method: 'dom-matrix'});
  } else {
    send({type: 'status', message: '没有找到结构明确的课程。请先打开“个人课表”、选好学期并查询，再点提取。'});
  }
})();
''';
