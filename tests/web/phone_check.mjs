// 실제 웹 빌드를 헤드리스 크롬에서 휴대폰처럼(화면 844x390, 터치, 모바일 UA) 열어 화면을 찍는다.
// 엔진 안의 테스트로는 못 잡는 문제(브라우저의 기기 감지, 화면 크기에 따른 배치)를 확인하는 용도다.
// 의존성 없이 Node 22의 내장 fetch/WebSocket으로 크롬 디버깅 프로토콜을 직접 쓴다.
//
//   (웹 빌드 폴더에서) python3 -m http.server 8123
//   TAPS="510,345,60000" node tests/web/phone_check.mjs http://127.0.0.1:8123/ /tmp/web mobile
//
// TAPS는 "x,y,대기ms;..." 형식의 터치 목록. 위 예는 PLAY 화면의 START MATCH를 누르고 60초 기다린다.
// GESTURES로 누르고 있기·끌기·중간 화면 찍기를 이어서 할 수 있다(아래 코드의 주석 참고).
// 결과: <outPrefix>_menu.png, <outPrefix>_game.png 와 브라우저 콘솔 로그.
// GPU가 없는 환경에서는 소프트웨어 렌더링이라 매우 느리다(게임 화면까지 1분 안팎).
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
const [url, out, kind = 'mobile'] = process.argv.slice(2);
const port = 9333;
const chrome = spawn('google-chrome', [
  '--headless=new', `--remote-debugging-port=${port}`, '--no-sandbox', '--disable-gpu-sandbox',
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist',
  '--autoplay-policy=no-user-gesture-required', '--user-data-dir=/tmp/chrome-prof-' + Date.now(), 'about:blank',
], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) {
  await sleep(300);
  try { target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).find((t) => t.type === 'page'); } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0; const pending = new Map(); const logs = [];
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result ?? msg.error); pending.delete(msg.id); }
  if (msg.method === 'Runtime.consoleAPICalled') logs.push(msg.params.type + ': ' + msg.params.args.map((a) => a.value ?? a.description ?? '').join(' '));
  if (msg.method === 'Runtime.exceptionThrown') logs.push('EXCEPTION: ' + (msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text));
};
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const shot = async (name) => { const r = await send('Page.captureScreenshot', { format: 'png' }); writeFileSync(`${out}_${name}.png`, Buffer.from(r.data, 'base64')); console.log('SHOT', name); };
const tap = async (x, y) => {
  if (kind === 'mobile') {
    await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y }] });
    await sleep(80);
    await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else {
    await send('Input.dispatchMouseEvent', { type: 'mousePressed', x, y, button: 'left', clickCount: 1 });
    await send('Input.dispatchMouseEvent', { type: 'mouseReleased', x, y, button: 'left', clickCount: 1 });
  }
};
await send('Runtime.enable'); await send('Page.enable');
if (kind === 'mobile') {
  // SIZE=390x844 처럼 주면 세로 화면으로 본다.
  const [width, height] = (process.env.SIZE ?? '844x390').split('x').map(Number);
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: true, screenOrientation: width > height ? { type: 'landscapePrimary', angle: 90 } : { type: 'portraitPrimary', angle: 0 } });
  await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
  await send('Emulation.setUserAgentOverride', { userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S918N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36' });
} else {
  await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
}
const t0 = Date.now();
await send('Page.navigate', { url });
// 메뉴가 뜰 때까지: 캔버스가 생기고 엔진이 돌기 시작하면 로그가 찍힌다.
for (let i = 0; i < 90; i++) { await sleep(2000); if (logs.some((l) => /Godot Engine|OpenGL/.test(l))) break; }
console.log('ENGINE_START_SEC', ((Date.now() - t0) / 1000).toFixed(0));
await sleep(Number(process.env.MENU_WAIT ?? 25000));
await shot('menu');
const info = await send('Runtime.evaluate', { expression: `JSON.stringify({w: innerWidth, h: innerHeight, coarse: matchMedia('(pointer: coarse)').matches, touch: navigator.maxTouchPoints, gl: (()=>{const c=document.createElement('canvas').getContext('webgl2'); return c ? [c.getParameter(c.VERSION), !!c.getExtension('WEBGL_compressed_texture_astc'), !!c.getExtension('WEBGL_compressed_texture_etc'), !!c.getExtension('WEBGL_compressed_texture_s3tc'), !!c.getExtension('EXT_texture_compression_bptc')] : null})()})`, returnByValue: true });
console.log('PAGE', info.result?.value);
const taps = (process.env.TAPS ?? '').split(';').filter(Boolean).map((p) => p.split(',').map(Number));
for (const [x, y, wait] of taps) { await tap(x, y); await sleep(wait ?? 3000); }
// GESTURES="hold,x,y,ms;holdshot,x,y,ms,name;drag,x1,y1,x2,y2,ms;shot,name"
// : 누르고 있기, 누른 채 찍기, 끌기(끝에서 ms 동안 유지), 화면 찍기.
const touchPoint = (x, y, id) => ({ x, y, id });
for (const g of (process.env.GESTURES ?? '').split(';').filter(Boolean)) {
  const [kind2, ...rest] = g.split(',');
  const n = rest.map(Number);
  if (kind2 === 'hold') {
    await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [touchPoint(n[0], n[1], 1)] });
    await sleep(n[2]);
    await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else if (kind2 === 'holdshot') {
    // 누른 채로 화면을 찍는다: holdshot,x,y,ms,이름
    await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [touchPoint(n[0], n[1], 1)] });
    await sleep(n[2]);
    await shot(rest[3]);
    await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else if (kind2 === 'drag') {
    await send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [touchPoint(n[0], n[1], 1)] });
    for (let i = 1; i <= 10; i++) {
      await sleep(120);
      const x = n[0] + ((n[2] - n[0]) * i) / 10, y = n[1] + ((n[3] - n[1]) * i) / 10;
      await send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [touchPoint(x, y, 1)] });
    }
    await sleep(n[4] ?? 0);
    await send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  } else if (kind2 === 'shot') {
    await sleep(1500);
    await shot(rest[0]);
  }
}
if (taps.length && !process.env.GESTURES) { await sleep(Number(process.env.GAME_WAIT ?? 30000)); await shot('game'); }
console.log('LOGS'); for (const l of logs.filter((l) => !/^log: $/.test(l)).slice(0, 40)) console.log('  ' + l.slice(0, 220));
ws.close(); chrome.kill(); process.exit(0);
