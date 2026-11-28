"""fontTools의 WOFF2 해독에 필요한 brotli 대신, Node 내장 zlib으로 푼다(이 작업 환경 전용)."""
import subprocess

def decompress(data):
    script = "const z=require('zlib');const c=[];process.stdin.on('data',d=>c.push(d));process.stdin.on('end',()=>process.stdout.write(z.brotliDecompressSync(Buffer.concat(c))));"
    return subprocess.run(["node", "-e", script], input=data, capture_output=True, check=True).stdout

def compress(data, *args, **kwargs):
    raise NotImplementedError
