#!/usr/bin/env python3
# =====================================================================
# verify.py ── 本書（第二部）の主張を、実際に走らせて確かめる
#
#   emu68k.py（小さな68000エミュレータ）で各プログラムを実行し、
#   本文の主張（2A=2A／プリエンプション／特権違反／トレース／隣人破壊
#   など）が本当に成り立つかを機械的に検査します。
#
#   使い方：  python3 tools/verify.py      （part2-os/ で実行）
#            または  make verify
# =====================================================================
import os, sys, re
HERE=os.path.dirname(os.path.abspath(__file__))
OS=os.path.dirname(HERE)                      # part2-os/
sys.path.insert(0,HERE)
import emu68k

def asm(name): return os.path.join(OS,name)
def run(name, **kw):
    mac,meta=emu68k.run_program([asm(name)], **kw)
    return mac,meta

def alive(m,ntask=3,T=12,base=0xFF0020):
    return [m.read8(base+i*T+4) for i in range(ntask)]

# ---- 静的解析 ----
def count_yield_instrs(meta):
    syms,instrs,prog=meta
    ya=syms.get('Yield')
    seq=[i for i in instrs if i.addr>=ya]
    seq.sort(key=lambda i:i.addr)
    n=0
    for ins in seq:
        n+=1
        if ins.mnem=='rte': break
    return n

def src(name): return open(asm(name),encoding='utf-8').read()

def call_sub(mac, addr, max_steps=20000):
    """カーネルのサブルーチンを一つだけ呼んで、rts で帰ってくるまで走らせる。"""
    mac.A[7]=0x00FFFFF0; mac.sr=0x2700
    mac.A[7]-=4; mac.write32(mac.A[7], 0)      # 番地0を「帰る合図」に使う
    mac.pc=addr
    for _ in range(max_steps):
        if mac.pc==0: return True
        mac.step()
    return False

RESULTS=[]
def check(no, chapter, title, ok, detail):
    RESULTS.append((no,chapter,title,ok,detail))

# =====================================================================
# 検査
# =====================================================================
def main():
    # [1] ベクタ表：trap #0 の飛び先は SysYield（ベクタ32番＝$080）
    m,meta=run('coop.asm', max_steps=1, vblank=False)
    v32=m.read32(32*4); sysy=meta[0].get('SysYield')
    check(1,'第20章','trap #0 はベクタ32番へ（システムコールの玄関）', v32==sysy, f'vec32=${v32:06X} == SysYield=${sysy:06X}')

    # [2] 心臓部は13命令
    n=count_yield_instrs(meta)
    check(2,'第20章5節','Yield は13命令（心臓部）', n==13, f'実測 {n} 命令')

    # [3] 偽の履歴は66バイト（15本×4 + SR2 + PC4）
    ok='suba.l  #66' in src('coop.asm')
    check(3,'第20章5節','偽の履歴は66バイト（InitTask）', ok, 'suba.l #66,a1 を確認')

    # [4] coop：全員スーパーバイザで生まれる（偽SR=$2000）
    ok='#$2000,(a0)+' in src('coop.asm')
    check(4,'第20章','協調版のタスクは S=1（偽SR=$2000）', ok, '偽SR=$2000 を確認')

    # [5] meijin10：ユーザモードで生まれる（偽SR=$0000）
    ok='#$0000,(a0)+' in src('meijin10.asm')
    check(5,'第21章','完成版のタスクは S=0（偽SR=$0000）', ok, '偽SR=$0000 を確認')

    # [6] coop：2A = 2A（別タスクが同じ値まで進む）
    m,_=run('coop.asm', max_steps=600000, frame_steps=2000)
    a=m.read16(0xFF0004); b=m.read16(0xFF0006)
    check(6,'第20章','協調的マルチタスク（2A = 2A）', a>0 and abs(a-b)<=1, f'A={a} B={b}（差={abs(a-b)}）')

    # [7] preempt：誰も譲らないのに両方動く（プリエンプション）
    m,_=run('preempt.asm', max_steps=600000, frame_steps=2000)
    a=m.read16(0xFF0004); b=m.read16(0xFF0006)
    check(7,'第20章7節','プリエンプティブ（誰も譲らないのに両方動く）', a>0 and b>0, f'A={a} B={b}')

    # [8] meijin10：3タスクが同居し、全員生きている
    m,_=run('meijin10.asm', max_steps=600000, frame_steps=2000)
    al=alive(m); tick=m.read16(0xFF0000)
    check(8,'第26章5節','3タスク同居・全員生存（時計＋カウンタ＋ゾンビ）', tick>0 and al==[1,1,1], f'Tick={tick} alive={al}')

    # [9] meijin10：ゾンビが暴れても時刻は進む（プリエンプションが効く）
    check(9,'第20章7節','ゾンビが暴れても Tick が進む', tick>0, f'Tick={tick}')

    # [10] 特権違反：ユーザモードで特権命令を使ったタスクだけが死ぬ
    s=src('meijin10.asm').replace(
        "TaskZombie:\n    moveq   #0,d2\n.loop:\n    addq.w  #1,d2",
        "TaskZombie:\n    moveq   #0,d2\n.loop:\n    move.w  #$2700,sr\n    addq.w  #1,d2")
    tmp=asm('_verify_priv.asm'); open(tmp,'w',encoding='utf-8').write(s)
    try:
        m,_=emu68k.run_program([tmp], max_steps=300000, frame_steps=2000)
        al=alive(m); ec=m.read16(0xFF0008)
        check(10,'第25章','特権違反を捕まえる（犯人だけ死ぬ）', al==[1,1,0] and ec==0x8E, f'alive={al} ErrCode=${ec:04X}')
    finally:
        os.remove(tmp)

    # [11] トレース：Tビットで1命令ごとに例外が起き、命令数を数えられる
    m,_=run('trace.asm', max_steps=400000, frame_steps=2000)
    tc=m.read32(0xFF001C); ta=m.read32(0xFF0018)
    check(11,'第25章4節','トレース機構（ステップ実行の正体）', tc>0, f'TraceCount={tc} TraceAddr=${ta:06X}')

    # [12] 隣人破壊：task0 の配列あふれで、無関係な task1 が死ぬ（保護は半分）
    m,_=run('crash.asm', max_steps=600000, frame_steps=2000)
    al=alive(m); ec=m.read16(0xFF0008)
    check(12,'第26章3節','隣人を殺す（保護は半分しかない）', al[1]==0, f'alive={al} ErrCode=${ec:04X}')

    # [13] パッド：Aボタンを押すと、カウンタのタスクが数える
    #      （TH=1／TH=0 の二回読みが正しくできていないと、ここで落ちる）
    m,_=run('meijin10.asm', max_steps=600000, frame_steps=2000)
    idle=m.read16(0xFF0012)                       # ShowSlot[1] = カウンタ
    m,_=run('meijin10.asm', max_steps=600000, frame_steps=2000, pad='A')
    held=m.read16(0xFF0012)
    check(13,'第24章5節','Aボタンが届く（パッドの二回読み）', idle==0 and held>0,
          f'無押下={idle} A押下={held}')

    # [14] ホットキー：Start+A の同時押しで、ゾンビだけが死ぬ
    m,_=run('meijin10.asm', max_steps=600000, frame_steps=2000, pad='START+A')
    al=alive(m)
    check(14,'第25章6節','ホットキー（Start+A）でゾンビを殺せる', al==[1,1,0], f'alive={al}')

    # [15] 貸出係：Alloc は同じ部屋を二度貸さない。Free で戻る（第26章2節）
    m,meta=run('meijin10.asm', max_steps=1, vblank=False)
    sy=meta[0]
    rooms=[]
    for _ in range(3):
        call_sub(m, sy['Alloc']); rooms.append(m.A[0])
    m.A[0]=rooms[1]; call_sub(m, sy['Free'])      # 二つめを返す
    call_sub(m, sy['Alloc']); again=m.A[0]        # 返した部屋が、また貸される
    ok = (rooms==[sy['AllocPool'], sy['AllocPool']+256, sy['AllocPool']+512]
          and again==rooms[1])
    check(15,'第26章2節','貸出係（Alloc / Free）が、同じ部屋を二度貸さない', ok,
          '貸出=[%s] 返却後の再貸出=$%06X'%(', '.join('$%06X'%r for r in rooms), again))

    # [16] ホットキー：二つのボタンを別々のフレームで押しても効く
    #      （エッジ同士の同時成立で判定していると、ここが通らない）
    def hotkey_staged(a_frame, start_frame):
        syms,instrs,prog,mem = emu68k.assemble([asm('meijin10.asm')])
        mac = emu68k.Machine(syms,instrs,prog,mem)
        st = {'f':0}
        def on_frame(mm):
            st['f'] += 1
            if st['f'] == a_frame:     mm.pad_th0 &= ~(1<<4) & 0xFF   # A
            if st['f'] == start_frame: mm.pad_th0 &= ~(1<<5) & 0xFF   # START
        mac.run(max_steps=600000, frame_steps=2000, on_frame=on_frame)
        return alive(mac)
    a_first     = hotkey_staged(5, 8)   # A を押しながら、あとで START
    start_first = hotkey_staged(8, 5)   # START を押しながら、あとで A
    check(16,'第25章6節','ホットキーは、二つを別々のフレームで押しても効く',
          a_first==[1,1,0] and start_first==[1,1,0],
          f'A先={a_first} START先={start_first}')

    # ---- レポート ----
    print("="*64)
    print(" MeijinOS68k ── 本書の主張を、実際に走らせて検査")
    print("="*64)
    ok_n=0
    for no,ch,title,ok,detail in RESULTS:
        mark='OK  ' if ok else 'FAIL'
        print(f"[{no:2}] {ch}：{title}")
        print(f"     [{mark}] {detail}")
        ok_n+=1 if ok else 0
    print("-"*64)
    print(f"結果： {ok_n} / {len(RESULTS)} 項目が OK")
    return 0 if ok_n==len(RESULTS) else 1

if __name__=='__main__':
    sys.exit(main())
