// Lane A118 (track S3): the strict JSON parser both validators share, a line-for-line port of FParser in Game/Source/JamCore/Private/JamJson.cpp.
// One rule, both sides (schema/README.md "The rule for lane A1"): a duplicate key is an error at the pointer of the repeated key; a leading UTF-8 byte order
// mark is tolerated (editors add it; the C++ loader always did); a syntax error is reported at the pointer of the value being read, with the same words and
// the same character offset (UTF-16 units, as JavaScript strings and Unreal's TCHAR count them); nesting deeper than 64 is refused; a number that is not
// finite (1e999) is refused while parsing.
// parseStrict(text) -> { value } or { error: 'at <pointer>: the file is not valid JSON (...).' }
const esc = (k) => String(k).replace(/~/g, '~0').replace(/\//g, '~1');
const childPtr = (ptr, key) => `${ptr}/${esc(key)}`;
const show = (p) => (p === '' ? '/' : p);

export function parseStrict(text) {
  const s = String(text);
  const len = s.length;
  let pos = 0;
  let error = '';
  const fail = (ptr, why) => {
    if (!error) error = `at ${show(ptr)}: the file is not valid JSON (${why} at character ${pos}).`;
    return undefined;
  };
  const skipWs = () => {
    while (pos < len) {
      const c = s[pos];
      if (c === ' ' || c === '\t' || c === '\n' || c === '\r') ++pos; else break;
    }
  };
  const isDigit = (c) => c >= '0' && c <= '9';
  const FAIL = Symbol('fail');
  function parseString(ptr) {
    if (pos >= len || s[pos] !== '"') { fail(ptr, 'expected a string'); return FAIL; }
    ++pos;
    let out = '';
    while (pos < len) {
      const c = s[pos++];
      if (c === '"') return out;
      if (c.charCodeAt(0) < 0x20) { fail(ptr, 'control character in a string'); return FAIL; }
      if (c !== '\\') { out += c; continue; }
      if (pos >= len) break;
      const e = s[pos++];
      switch (e) {
        case '"': out += '"'; break;
        case '\\': out += '\\'; break;
        case '/': out += '/'; break;
        case 'b': out += '\b'; break;
        case 'f': out += '\f'; break;
        case 'n': out += '\n'; break;
        case 'r': out += '\r'; break;
        case 't': out += '\t'; break;
        case 'u': {
          if (pos + 4 > len) { fail(ptr, 'bad \\u escape'); return FAIL; }
          let code = 0;
          for (let i = 0; i < 4; ++i) {
            const h = s[pos++];
            code <<= 4;
            if (h >= '0' && h <= '9') code |= h.charCodeAt(0) - 48;
            else if (h >= 'a' && h <= 'f') code |= h.charCodeAt(0) - 97 + 10;
            else if (h >= 'A' && h <= 'F') code |= h.charCodeAt(0) - 65 + 10;
            else { fail(ptr, 'bad \\u escape'); return FAIL; }
          }
          out += String.fromCharCode(code);
          break;
        }
        default: fail(ptr, 'bad escape'); return FAIL;
      }
    }
    fail(ptr, 'unterminated string');
    return FAIL;
  }
  function parseNumber(ptr) {
    const start = pos;
    if (pos < len && s[pos] === '-') ++pos;
    if (pos >= len) { fail(ptr, 'bad number'); return FAIL; }
    if (s[pos] === '0') ++pos;
    else if (s[pos] >= '1' && s[pos] <= '9') { while (pos < len && isDigit(s[pos])) ++pos; }
    else { fail(ptr, 'bad number'); return FAIL; }
    if (pos < len && s[pos] === '.') {
      ++pos;
      if (pos >= len || !isDigit(s[pos])) { fail(ptr, 'bad number'); return FAIL; }
      while (pos < len && isDigit(s[pos])) ++pos;
    }
    if (pos < len && (s[pos] === 'e' || s[pos] === 'E')) {
      ++pos;
      if (pos < len && (s[pos] === '+' || s[pos] === '-')) ++pos;
      if (pos >= len || !isDigit(s[pos])) { fail(ptr, 'bad number'); return FAIL; }
      while (pos < len && isDigit(s[pos])) ++pos;
    }
    const v = Number(s.slice(start, pos));
    if (!Number.isFinite(v)) { fail(ptr, 'number out of range'); return FAIL; }
    return v;
  }
  const literal = (w) => { if (s.startsWith(w, pos)) { pos += w.length; return true; } return false; };
  function parseValue(ptr, depth) {
    if (depth > 64) { fail(ptr, 'nested too deep'); return FAIL; }
    skipWs();
    if (pos >= len) { fail(ptr, 'unexpected end'); return FAIL; }
    const c = s[pos];
    if (c === '{') {
      const obj = {};
      const seen = new Set();
      ++pos;
      skipWs();
      if (pos < len && s[pos] === '}') { ++pos; return obj; }
      for (;;) {
        skipWs();
        const key = parseString(ptr);
        if (key === FAIL) return FAIL;
        const cp = childPtr(ptr, key);
        if (seen.has(key)) {
          if (!error) error = `at ${show(cp)}: duplicate key "${key}"; a key may appear only once in an object.`;
          return FAIL;
        }
        seen.add(key);
        skipWs();
        if (pos >= len || s[pos] !== ':') { fail(ptr, "expected ':'"); return FAIL; }
        ++pos;
        const v = parseValue(cp, depth + 1);
        if (v === FAIL) return FAIL;
        Object.defineProperty(obj, key, { value: v, enumerable: true, writable: true, configurable: true });
        skipWs();
        if (pos < len && s[pos] === ',') { ++pos; continue; }
        if (pos < len && s[pos] === '}') { ++pos; return obj; }
        fail(ptr, "expected ',' or '}'");
        return FAIL;
      }
    }
    if (c === '[') {
      const arr = [];
      ++pos;
      skipWs();
      if (pos < len && s[pos] === ']') { ++pos; return arr; }
      for (;;) {
        const v = parseValue(childPtr(ptr, arr.length), depth + 1);
        if (v === FAIL) return FAIL;
        arr.push(v);
        skipWs();
        if (pos < len && s[pos] === ',') { ++pos; continue; }
        if (pos < len && s[pos] === ']') { ++pos; return arr; }
        fail(ptr, "expected ',' or ']'");
        return FAIL;
      }
    }
    if (c === '"') return parseString(ptr);
    if (c === '-' || isDigit(c)) return parseNumber(ptr);
    if (literal('true')) return true;
    if (literal('false')) return false;
    if (literal('null')) return null;
    fail(ptr, 'unexpected character');
    return FAIL;
  }
  if (len > 0 && s.charCodeAt(0) === 0xfeff) pos = 1;
  let root = parseValue('', 0);
  if (root !== FAIL) {
    skipWs();
    if (pos !== len) { fail('', 'text after the end of the JSON value'); root = FAIL; }
  }
  return root === FAIL ? { error } : { value: root };
}
