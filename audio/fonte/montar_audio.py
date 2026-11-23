"""Gera todos os sons do Kaerith: O Despertar por código (chiptune 16 bits, nada gravado nem copiado).

Uso (na pasta do projeto):  python audio/fonte/montar_audio.py
Precisa de Python 3 + numpy, e do ffmpeg (com libvorbis) no PATH para as músicas em .ogg.

Saída:
  audio/efeitos/*.wav   efeitos curtos (16 bits, mono, 32 kHz, a taxa do SNES)
  audio/musica/*.ogg    músicas de fundo em laço (Ogg Vorbis, mono, 32 kHz)

Todas as melodias abaixo foram escritas para o jogo (PROVISÓRIAS, 2026-11-23).
"""
import os
import subprocess
import sys
import wave

import numpy as np

TAXA = 32000
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # .../audio
PASTA_EF = os.path.join(RAIZ, "efeitos")
PASTA_MU = os.path.join(RAIZ, "musica")

NOMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(nota: str) -> int:
    """'A4', 'C#5', 'Bb3' -> número MIDI."""
    letra = nota[0]
    resto = nota[1:]
    ac = 0
    while resto and resto[0] in "#b":
        ac += 1 if resto[0] == "#" else -1
        resto = resto[1:]
    return 12 * (int(resto) + 1) + NOMES[letra] + ac


def freq(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ------------------------------------------------------------------ ondas
def fase_de(f) -> np.ndarray:
    """f: número ou vetor de frequências por amostra -> fase acumulada (0..1)."""
    return np.cumsum(np.asarray(f, dtype=np.float64) / TAXA) % 1.0


def quadrada(fase, duty=0.5):
    return np.where(fase < duty, 1.0, -1.0)


def triangulo(fase, passos=16):
    t = 4.0 * np.abs(fase - 0.5) - 1.0
    return np.round(t * (passos / 2)) / (passos / 2)        # degraus como no chip


_ruido_cache = {}


def ruido(n, taxa_hz=8000.0, seed=1):
    """Ruído 'sample and hold' (o chiado do chip)."""
    rng = np.random.default_rng(seed)
    passo = max(1, int(TAXA / taxa_hz))
    base = rng.uniform(-1, 1, n // passo + 2)
    return np.repeat(base, passo)[:n]


def env_adsr(n, a=0.004, d=0.08, s=0.7, r=0.03, gate=None):
    gate = n if gate is None else min(n, gate)
    e = np.zeros(n)
    na, nd, nr = int(a * TAXA), int(d * TAXA), int(r * TAXA)
    i = 0
    if na > 0:
        k = min(na, gate)
        e[:k] = np.linspace(0, 1, na)[:k]
        i = k
    if i < gate:
        k = min(nd, gate - i)
        e[i:i + k] = np.linspace(1, s, max(nd, 1))[:k]
        i += k
    if i < gate:
        e[i:gate] = s
    nivel = e[gate - 1] if gate > 0 else 0
    if gate < n:
        k = min(nr, n - gate)
        e[gate:gate + k] = np.linspace(nivel, 0, max(nr, 1))[:k]
    return e


def env_queda(n, tempo):
    """Decaimento exponencial (tempo = segundos até ~1/e)."""
    t = np.arange(n) / TAXA
    return np.exp(-t / max(tempo, 1e-4))


def seg(s):
    return int(round(s * TAXA))


def tom(f0, dur, onda="q", duty=0.5, f1=None, vol=1.0, a=0.003, d=0.05, s=0.7, r=0.02, vib=0.0, vib_hz=6.0):
    """Um tom com deslize (f0 -> f1) e envelope."""
    n = seg(dur)
    if f1 is None:
        f = np.full(n, float(f0))
    else:
        f = np.geomspace(f0, f1, n)
    if vib > 0:
        t = np.arange(n) / TAXA
        f = f * 2 ** (vib * np.sin(2 * np.pi * vib_hz * t) / 12.0)
    ph = fase_de(f)
    w = quadrada(ph, duty) if onda == "q" else triangulo(ph)
    return w * env_adsr(n, a, d, s, r, gate=n - seg(r)) * vol


def juntar(*partes, gap=0.0):
    out = []
    for p in partes:
        out.append(p)
        if gap > 0:
            out.append(np.zeros(seg(gap)))
    return np.concatenate(out)


def mistura(*faixas):
    n = max(len(x) for x, _ in faixas)
    out = np.zeros(n)
    for x, ini in faixas:
        i = seg(ini)
        if i + len(x) > len(out):
            out = np.concatenate([out, np.zeros(i + len(x) - len(out))])
        out[i:i + len(x)] += x
    return out


def eco(x, atraso, retorno=0.35, mix=0.3, vezes=5):
    k = seg(atraso)
    out = np.concatenate([x, np.zeros(k * vezes)])
    seco = out.copy()
    g = mix
    for i in range(1, vezes + 1):
        out[k * i:k * i + len(x)] += x * g
        g *= retorno
    return out if len(seco) else out


def normalizar(x, pico=0.8):
    m = np.max(np.abs(x))
    return x * (pico / m) if m > 0 else x


def gravar_wav(nome, x, pico=0.8):
    x = normalizar(x, pico)
    # 4 ms de rampa no fim para não estalar
    k = min(len(x), seg(0.004))
    x[-k:] *= np.linspace(1, 0, k)
    dados = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    os.makedirs(PASTA_EF, exist_ok=True)
    with wave.open(os.path.join(PASTA_EF, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados)


# ------------------------------------------------------------------ efeitos
def efeitos():
    E = {}
    # interface
    E["toque"] = tom(1318.5, 0.045, duty=0.25, f1=1760, a=0.001, d=0.02, s=0.5, r=0.015)
    E["voltar"] = tom(1046.5, 0.05, duty=0.25, f1=784, a=0.001, d=0.02, s=0.5, r=0.015)
    E["abrir"] = juntar(tom(784, 0.04, duty=0.25, s=0.6), tom(1174.7, 0.07, duty=0.25, s=0.6))
    for i, f in enumerate([880.0, 987.8, 830.6]):          # bips do diálogo (3 alturas, alternadas)
        E["bip_%d" % (i + 1)] = tom(f, 0.032, duty=0.5, a=0.001, d=0.01, s=0.8, r=0.008) * 0.8
    E["erro"] = juntar(tom(196, 0.09, duty=0.5, s=0.9), tom(155.6, 0.16, duty=0.5, s=0.9), gap=0.02)

    # combate
    n = seg(0.2)
    sopro = ruido(n, 12000, 3) * env_adsr(n, 0.01, 0.05, 0.6, 0.12, gate=seg(0.06))
    E["ataque"] = mistura((sopro, 0), (tom(660, 0.12, duty=0.125, f1=220, s=0.4) * 0.35, 0))
    m = juntar(*[tom(freq(x), 0.045, duty=0.25, s=0.8) for x in (72, 76, 79, 84, 88)])
    brilho = ruido(len(m), 16000, 4) * env_queda(len(m), 0.08) * 0.25
    E["magia"] = eco(m + brilho, 0.06, 0.4, 0.45, 3)
    n = seg(0.18)
    pancada = ruido(n, 6000, 5) * env_queda(n, 0.04)
    E["dano"] = mistura((pancada, 0), (tom(180, 0.14, duty=0.5, f1=60, a=0.001, d=0.04, s=0.5, r=0.05) * 0.6, 0))
    n = seg(0.26)
    E["dano_heroi"] = mistura((ruido(n, 4000, 6) * env_queda(n, 0.06), 0), (tom(140, 0.24, duty=0.5, f1=45, a=0.001, d=0.05, s=0.6, r=0.08) * 0.7, 0))
    n = seg(0.3)
    E["critico"] = mistura((ruido(n, 9000, 7) * env_queda(n, 0.07), 0),
                           (tom(220, 0.2, duty=0.5, f1=50, a=0.001, s=0.6) * 0.7, 0),
                           (tom(1975.5, 0.12, duty=0.25, a=0.001, d=0.03, s=0.4, r=0.06) * 0.4, 0.03))
    n = seg(0.22)
    E["errou"] = mistura((ruido(n, 10000, 8) * env_adsr(n, 0.02, 0.06, 0.4, 0.12, gate=seg(0.08)) * 0.6, 0), (tom(523, 0.18, onda="t", f1=330, s=0.5) * 0.4, 0))
    E["cura"] = eco(juntar(*[tom(freq(x), 0.06, onda="t", s=0.9) for x in (67, 72, 76, 79, 84)]), 0.07, 0.4, 0.4, 3)
    bolhas = [tom(f, 0.05, duty=0.25, f1=f * 1.6, s=0.6) for f in (400, 520, 450, 640, 560)]
    E["pocao"] = juntar(*bolhas, gap=0.02)
    E["queda"] = tom(440, 0.42, duty=0.5, f1=70, a=0.002, d=0.1, s=0.6, r=0.1) * 0.7 + \
        ruido(seg(0.42), 3000, 9) * env_queda(seg(0.42), 0.12) * 0.4
    E["queda_heroi"] = juntar(tom(392, 0.18, onda="t", s=0.9), tom(311, 0.18, onda="t", s=0.9), tom(233, 0.4, onda="t", s=0.8, r=0.2))
    E["onda"] = juntar(tom(587.3, 0.09, duty=0.5, s=0.9), tom(880, 0.16, duty=0.5, s=0.9), gap=0.03)
    E["condicao"] = tom(300, 0.16, duty=0.125, f1=600, s=0.7, vib=1.5, vib_hz=18)

    # vitória: fanfarra curta (pulso + triângulo)
    def fanfarra(notas, baixo, passo):
        lead = juntar(*[tom(freq(midi(nm)), passo * d, duty=0.5, s=0.75, r=0.03, vib=0.12 if d >= 4 else 0) for nm, d in notas])
        bx = juntar(*[tom(freq(midi(nm)), passo * d, onda="t", s=0.9) for nm, d in baixo])
        har = juntar(*[tom(freq(midi(nm) - 4), passo * d, duty=0.25, s=0.6) for nm, d in notas])
        return mistura((eco(lead, passo * 1.5, 0.3, 0.25, 3) * 0.55, 0), (bx * 0.6, 0), (har * 0.18, 0))
    E["vitoria"] = fanfarra([("C5", 1), ("E5", 1), ("G5", 1), ("C6", 3), ("A5", 1), ("B5", 1), ("C6", 6)],
                            [("C3", 3), ("G3", 3), ("F3", 2), ("C3", 6)], 0.11)
    # derrota: descendo, menor
    lead = juntar(*[tom(freq(midi(nm)), 0.2 * d, duty=0.5, s=0.7, r=0.05, vib=0.15) for nm, d in
                    [("E5", 1), ("D#5", 1), ("D5", 1), ("C#5", 4)]])
    bx = juntar(*[tom(freq(midi(nm)), 0.2 * d, onda="t", s=0.9, r=0.1) for nm, d in [("A3", 3), ("A2", 4)]])
    E["derrota"] = mistura((eco(lead, 0.18, 0.3, 0.3, 3) * 0.55, 0), (bx * 0.6, 0))
    E["nivel"] = eco(juntar(*[tom(freq(x), 0.07, duty=0.25, s=0.8) for x in (72, 76, 79, 84, 79, 84, 88, 91)]) * 0.7, 0.07, 0.35, 0.3, 3)

    # QR, baú, prêmio
    E["qr_lido"] = juntar(tom(1567.98, 0.06, duty=0.5, s=0.9), tom(2093, 0.16, duty=0.5, s=0.8, r=0.08), gap=0.01)
    n = seg(0.25)
    rangido = (quadrada(fase_de(np.geomspace(90, 140, n)), 0.1) * 0.3 + ruido(n, 2500, 11) * 0.3) * env_adsr(n, 0.02, 0.05, 0.8, 0.05)
    brilho = eco(juntar(*[tom(freq(x), 0.05, duty=0.25, s=0.8) for x in (79, 83, 86, 91, 95)]), 0.05, 0.4, 0.4, 3)
    E["bau"] = mistura((rangido, 0), (brilho * 0.6, 0.22))
    E["moeda"] = juntar(tom(987.8, 0.06, duty=0.5, s=0.9), tom(1318.5, 0.22, duty=0.5, s=0.7, r=0.12))
    # despertar: subida longa + acorde
    n = seg(1.2)
    subida = quadrada(fase_de(np.geomspace(110, 880, n)), 0.25) * np.linspace(0.1, 0.6, n)
    subida += ruido(n, 14000, 12) * np.linspace(0, 0.25, n)
    acorde = sum(tom(freq(x), 1.0, onda="q", duty=0.5, s=0.7, r=0.4, vib=0.15) for x in (69, 76, 81, 85)) / 3
    E["despertar"] = eco(mistura((subida, 0), (acorde, 1.15)), 0.12, 0.4, 0.3, 4)

    for nome, x in E.items():
        gravar_wav(nome, x, 0.75 if nome.startswith("bip") else 0.85)
    return list(E)


# ------------------------------------------------------------------ músicas
ACORDES = {
    "Dm": [62, 65, 69], "Bb": [58, 62, 65], "F": [60, 65, 69], "C": [60, 64, 67], "A": [61, 64, 69],
    "Gm": [62, 67, 70], "Am": [60, 64, 69], "G": [62, 67, 71], "E": [59, 64, 68], "Em": [59, 64, 67],
    "D": [62, 66, 69], "B": [63, 66, 71],
}
RAIZES = {"Dm": 38, "Bb": 34, "F": 41, "C": 36, "A": 33, "Gm": 43, "Am": 33, "G": 43, "E": 40, "Em": 40, "D": 38, "B": 35}


def ler_melodia(texto):
    """'A4:4 D5:4 -:8' -> [(midi ou None, passos)]"""
    out = []
    for tk in texto.split():
        n, d = tk.split(":")
        out.append((None if n == "-" else midi(n), int(d)))
    return out


def musica(nome, bpm, acordes, melodias, estilo):
    passo = 60.0 / bpm / 4.0            # semicolcheia
    barras = len(acordes)
    total_passos = barras * 16
    n_total = seg(total_passos * passo)

    def em(p):
        return seg(p * passo)

    lead = np.zeros(n_total * 2)
    arp = np.zeros(n_total * 2)
    baixo = np.zeros(n_total * 2)
    bat = np.zeros(n_total * 2)

    def por(buf, x, p):
        i = em(p)
        x = x[: len(buf) - i]
        buf[i:i + len(x)] += x

    for volta in range(2):                 # duas voltas: a 2ª já tem o eco/cauda da 1ª (laço sem emenda)
        base = volta * total_passos
        # melodia
        p = 0
        notas = []
        for barra, mel in enumerate(melodias):
            m = ler_melodia(mel)
            soma = sum(d for _, d in m)
            assert soma == 16, (nome, barra + 1, soma)
            notas += m
        for nm, d in notas:
            if nm is not None:
                dur = d * passo
                x = tom(freq(nm), dur * 0.92, duty=estilo["duty_lead"], s=0.75, d=0.08, r=0.03,
                        vib=0.18 if dur > 0.3 else 0.0, vib_hz=5.5)
                por(lead, x, base + p)
            p += d
        # acompanhamento
        for b, ac in enumerate(acordes):
            notas_ac = ACORDES[ac]
            raiz = RAIZES[ac]
            for s in range(16):
                pp = base + b * 16 + s
                # arpejo
                if estilo["arpejo"] == "semi":
                    nt = notas_ac[s % 3] + 12
                    por(arp, tom(freq(nt), passo * 0.8, duty=0.125, s=0.6, d=0.03, r=0.01), pp)
                elif estilo["arpejo"] == "lento" and s % 4 == 0:
                    nt = notas_ac[(s // 4) % 3] + 12
                    por(arp, tom(freq(nt), passo * 3.8, onda="t", s=0.8, d=0.1, r=0.1), pp)
                # baixo
                padrao = estilo["baixo"]
                if padrao == "oito" and s % 2 == 0:
                    nt = raiz + (12 if s % 4 == 2 else 0)
                    por(baixo, tom(freq(nt), passo * 1.7, onda="t", s=0.9, d=0.02, r=0.02), pp)
                elif padrao == "galope" and s in (0, 3, 6, 8, 11, 14):
                    nt = raiz + (7 if s in (6, 14) else 0)
                    por(baixo, tom(freq(nt), passo * 1.6, onda="t", s=0.9, d=0.02, r=0.02), pp)
                elif padrao == "longo" and s % 8 == 0:
                    por(baixo, tom(freq(raiz), passo * 7.6, onda="t", s=0.9, d=0.2, r=0.2), pp)
                # bateria
                kit = estilo["bateria"]
                if kit:
                    if s in kit.get("bumbo", ()):
                        k = tom(150, 0.09, onda="q", duty=0.5, f1=40, a=0.001, d=0.03, s=0.4, r=0.03) * 0.8
                        por(bat, k, pp)
                    if s in kit.get("caixa", ()):
                        nn = seg(0.12)
                        por(bat, ruido(nn, 7000, 20 + s) * env_queda(nn, 0.035) * 0.7, pp)
                    if s in kit.get("chimbal", ()):
                        nn = seg(0.03)
                        por(bat, ruido(nn, 16000, 40 + s) * env_queda(nn, 0.008) * 0.35, pp)

    lead = eco(lead, passo * 3, 0.35, 0.28, 4)[: n_total * 2]
    arp = eco(arp, passo * 3, 0.3, 0.2, 3)[: n_total * 2]
    mix = lead * estilo["v_lead"] + arp * estilo["v_arp"] + baixo * estilo["v_baixo"] + bat * estilo["v_bat"]
    x = mix[n_total: n_total * 2]                       # 2ª volta
    x = normalizar(x, 0.7)
    os.makedirs(PASTA_MU, exist_ok=True)
    tmp = os.path.join(PASTA_MU, nome + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    destino = os.path.join(PASTA_MU, nome + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", destino], check=True)
    os.remove(tmp)
    return len(x) / TAXA


def musicas():
    tempos = {}
    # Tema (Início, mapa, Loja...): aventura em ré menor
    tempos["tema"] = musica("tema", 104,
        ["Dm", "Bb", "F", "C", "Dm", "Bb", "C", "A", "Bb", "C", "Am", "Dm", "Gm", "Bb", "A", "A"],
        ["A4:4 D5:4 E5:2 F5:6", "D5:4 F5:4 G5:2 F5:2 D5:4", "C5:4 F5:4 A5:6 G5:2", "E5:8 -:4 C5:2 E5:2",
         "F5:4 E5:2 D5:2 A4:8", "Bb4:4 D5:4 F5:4 D5:4", "E5:4 G5:4 C6:4 Bb5:4", "A5:12 -:4",
         "D6:4 C6:2 Bb5:2 F5:8", "E5:4 G5:2 A5:2 G5:8", "A5:4 C6:4 E6:4 C6:4", "D6:8 A5:8",
         "Bb5:4 A5:2 G5:2 D5:8", "F5:4 G5:2 A5:2 Bb5:8", "A5:4 G5:2 F5:2 E5:4 C#5:4", "E5:8 -:8"],
        {"duty_lead": 0.5, "arpejo": "semi", "baixo": "oito",
         "bateria": {"bumbo": (0, 8), "caixa": (4, 12), "chimbal": (2, 6, 10, 14)},
         "v_lead": 0.30, "v_arp": 0.10, "v_baixo": 0.42, "v_bat": 0.20})
    # Combate: lá menor, rápido
    tempos["combate"] = musica("combate", 150,
        ["Am", "Am", "F", "G", "Am", "Am", "F", "E", "Dm", "Am", "F", "G", "Dm", "Am", "E", "E"],
        ["A4:2 C5:2 E5:2 A5:4 G5:2 E5:2 C5:2", "D5:2 E5:4 C5:2 A4:4 B4:2 C5:2", "F5:4 E5:2 F5:2 A5:4 F5:2 C5:2",
         "G5:4 F5:2 E5:2 D5:4 B4:4", "A4:2 C5:2 E5:2 A5:4 B5:2 C6:2 B5:2", "A5:4 E5:4 C5:4 E5:4",
         "F5:2 G5:2 A5:2 C6:4 A5:2 F5:2 A5:2", "G#5:6 E5:2 B4:4 -:4",
         "D5:2 F5:2 A5:2 D6:6 C6:2 A5:2", "C6:4 B5:2 A5:2 E5:8", "F5:2 A5:2 C6:2 F6:6 E6:2 C6:2",
         "D6:4 B5:4 G5:4 D5:4", "F5:4 E5:2 D5:2 A5:4 F5:4", "E5:4 A5:4 C6:4 E6:4",
         "D6:2 C6:2 B5:2 G#5:2 B5:2 G#5:2 E5:4", "E5:4 G#5:4 B5:4 -:4"],
        {"duty_lead": 0.25, "arpejo": "semi", "baixo": "oito",
         "bateria": {"bumbo": (0, 6, 8, 10), "caixa": (4, 12), "chimbal": (0, 2, 4, 6, 8, 10, 12, 14)},
         "v_lead": 0.30, "v_arp": 0.09, "v_baixo": 0.45, "v_bat": 0.24})
    # Chefe: mi menor, galope e tensão
    tempos["chefe"] = musica("chefe", 160,
        ["Em", "Em", "F", "F", "Em", "Em", "D", "B", "C", "D", "Em", "Em", "C", "D", "B", "B"],
        ["E5:2 -:2 E5:2 F5:2 G5:4 F5:2 E5:2", "B4:4 E5:4 G5:2 F#5:2 E5:4", "F5:2 -:2 F5:2 G5:2 A5:4 G5:2 F5:2",
         "C5:4 F5:4 A5:4 C6:4", "B5:4 A5:2 G5:2 F#5:4 E5:4", "G5:2 F#5:2 E5:2 D5:2 E5:8",
         "F#5:4 A5:4 D6:4 C6:2 A5:2", "B5:8 D#5:4 F#5:4",
         "E5:2 G5:2 C6:4 B5:2 G5:2 E5:4", "F#5:2 A5:2 D6:4 C6:2 A5:2 F#5:4", "G5:4 B5:4 E6:8",
         "D6:2 B5:2 G5:2 E5:2 B4:8", "C6:4 B5:2 A5:2 G5:4 E5:4", "D6:4 C6:2 B5:2 A5:4 F#5:4",
         "B5:4 A5:2 G5:2 F#5:4 D#5:4", "B4:4 D#5:4 F#5:4 B5:4"],
        {"duty_lead": 0.5, "arpejo": "semi", "baixo": "galope",
         "bateria": {"bumbo": (0, 3, 6, 8, 11, 14), "caixa": (4, 12), "chimbal": (2, 6, 10, 14)},
         "v_lead": 0.30, "v_arp": 0.10, "v_baixo": 0.48, "v_bat": 0.24})
    # História (Prólogo, Chegada, criação, Despertar): lenta e misteriosa
    tempos["historia"] = musica("historia", 72,
        ["Am", "F", "C", "G", "Am", "F", "E", "E"],
        ["E5:8 C5:4 D5:4", "E5:8 A4:8", "G5:8 E5:4 C5:4", "D5:12 -:4",
         "A5:8 G5:4 E5:4", "F5:8 C5:8", "B4:4 D5:4 E5:4 G#5:4", "E5:12 -:4"],
        {"duty_lead": 0.25, "arpejo": "lento", "baixo": "longo", "bateria": None,
         "v_lead": 0.26, "v_arp": 0.30, "v_baixo": 0.40, "v_bat": 0.0})
    return tempos


if __name__ == "__main__":
    ef = efeitos()
    print("efeitos:", len(ef), ", ".join(ef))
    if "--sem-musica" not in sys.argv:
        for k, v in musicas().items():
            print("música %s: %.1f s" % (k, v))
