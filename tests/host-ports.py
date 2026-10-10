"""Real-plugin integration checks, no audio hardware or registry changes."""
import array, json, math, pathlib, statistics, struct, subprocess, sys, time
root = pathlib.Path(__file__).resolve().parents[1]
plugin = sys.argv[1]
checksum = sum((ord(c) * 820109) & 0xffff for c in plugin) & 0xffffffff
p = subprocess.Popen([str(root/'stage/vstbridgeapp32.exe'), plugin, f'{checksum:08X}',
    'port-test', '32-bit', 'W'], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    creationflags=subprocess.CREATE_NO_WINDOW)
def read(n):
    data = p.stdout.read(n)
    if len(data) != n: raise RuntimeError(f'host disconnected ({p.poll()})')
    return data
def word(): return struct.unpack('<I', read(4))[0]
def send(*values):
    p.stdin.write(struct.pack('<'+'I'*len(values), *values)); p.stdin.flush()
def cmd(*values):
    send(*values); assert word() == 0
def midi(port, status, a=0, b=0): cmd(7, (port<<24) | status | (a<<8) | (b<<16))
def sysex(port, data):
    send(8, (port<<24)|len(data)); p.stdin.write(data); p.stdin.flush(); assert word()==0
def render(n=480, channels=2):
    cmd(9 if channels==2 else 11,n)
    data=array.array('f'); data.frombytes(read(n*channels*4))
    assert all(math.isfinite(x) for x in data)
    return data
def energy(data): return sum(x*x for x in data)/max(1,len(data))
def drain():
    for _ in range(100): render()
def silence():
    for port in range(4):
        for channel in range(16): midi(port,0xb0+channel,120,0)
    drain()
results={}
try:
    assert word()==0
    lengths=[word() for _ in range(3)]
    version,uid,outputs=word(),word(),word()
    results['plugin']=[read(n).decode('ascii',errors='replace') for n in lengths]
    cmd(5,4,48000)
    for port in range(4):
        sysex(port, bytes.fromhex('f043104c00007e00f7'))
        for channel in range(16):
            midi(port,0xb0+channel,7,45); midi(port,0xb0+channel,91,0)
            midi(port,0xb0+channel,93,0); midi(port,0xc0+channel,16)
    drain()
    isolation=[]
    for port in range(4):
        silence(); midi(port,0x90,60+port*3,70)
        for _ in range(10): render()
        before=energy(render(4800)); assert before>1e-8,(port,'silent')
        for other in range(4):
            if other!=port:
                midi(other,0xb0,120,0)
                sysex(other,bytes.fromhex('f043104c00007e00f7'))
        after=energy(render(4800)); assert after>before*0.15,(port,'cross-port reset')
        midi(port,0xb0,120,0); drain()
        end=energy(render(4800)); assert end<before*0.001,(port,'stuck note',end,before)
        isolation.append({'port':chr(65+port),'energy':before,'after_other_resets':after,'after_own_off':end})
    results['isolation']=isolation
    # Every port/channel must accept MIDI independently.
    for port in range(4):
        for channel in range(16):
            midi(port,0xb0+channel,7,35); midi(port,0xc0+channel,16)
            midi(port,0x90+channel,40+channel,45)
    costs=[]; peak=0
    for _ in range(500):
        t=time.perf_counter(); samples=render(); costs.append((time.perf_counter()-t)*1000)
        peak=max(peak,max(map(abs,samples)))
    assert peak>0
    results['64_channel_stress']={'seconds':5,'peak':peak,'render_10ms_median':statistics.median(costs),'render_p99':sorted(costs)[494],'render_max':max(costs)}
    silence()
    routing=[]
    for port in range(4):
        midi(port,0xb0,7,45); midi(port,0xc0,16); midi(port,0x90,60,55)
        for _ in range(10): render(channels=4)
        audio=render(4800,channels=4)
        pair=[energy(audio[0::4])+energy(audio[1::4]),energy(audio[2::4])+energy(audio[3::4])]
        assert pair[port%2]>1e-8 and pair[1-port%2]<pair[port%2]*0.001,(port,pair)
        routing.append(pair)
        silence()
    results['four_audio_channel_routing']=routing
    send(0); p.wait(timeout=10); assert p.returncode==0,p.returncode
    results['success']=True
    print(json.dumps(results,indent=2))
finally:
    if p.poll() is None: p.kill(); p.wait()
