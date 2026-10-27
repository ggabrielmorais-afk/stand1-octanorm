# Gera os icones do STAND1 Octanorm na paleta dos plugins do Tarcisio
# (STAND1 Memorial / EVA): quadrado arredondado com gradiente rosa -> azul.
#   parede: preenchido, desenho branco (como o EVA)
#   porta:  fundo branco, borda e desenho em gradiente (como EVA KV / tomada)
# Uso: python ferramentas/icones.py   (gera em STAND1_Octanorm/icons)
import os
from PIL import Image, ImageDraw, ImageChops

ROSA = (230, 57, 138)   # --g-rosa #e6398a
AZUL = (26, 45, 184)    # --azul  #1A2DB8
BASE = 256
SAIDA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "STAND1_Octanorm", "icons")


def gradiente(t):
    """rosa no canto de cima/esquerda -> azul embaixo/direita"""
    g = Image.new("RGB", (t, t))
    px = g.load()
    for y in range(t):
        for x in range(t):
            k = (x + y) / (2.0 * (t - 1))
            px[x, y] = tuple(int(ROSA[i] + (AZUL[i] - ROSA[i]) * k) for i in range(3))
    return g


def mascara_quadrado(t, margem, raio):
    m = Image.new("L", (t, t), 0)
    ImageDraw.Draw(m).rounded_rectangle([margem, margem, t - margem, t - margem], raio, fill=255)
    return m


def desenho_parede(d, cor, k):
    # 4 montantes, travessa em cima e embaixo, folhas entre eles
    for x in (58, 104, 150, 196):
        d.rectangle([x * k - 7 * k, 62 * k, x * k + 7 * k, 194 * k], fill=cor)
    d.rectangle([52 * k, 62 * k, 204 * k, 76 * k], fill=cor)
    d.rectangle([52 * k, 180 * k, 204 * k, 194 * k], fill=cor)


def desenho_porta(d, cor, k, fundo):
    d.rectangle([72 * k, 54 * k, 184 * k, 204 * k], fill=cor)          # batente
    d.rectangle([88 * k, 70 * k, 168 * k, 204 * k], fill=fundo)       # vao
    d.polygon([(88 * k, 70 * k), (150 * k, 86 * k), (150 * k, 204 * k), (88 * k, 204 * k)], fill=cor)  # folha aberta
    d.ellipse([132 * k, 136 * k, 142 * k, 146 * k], fill=fundo)       # macaneta


def desenho_ilha(d, cor, k):
    # faixa da testeira em cima, apoiada em 2 montantes que descem ate o chao
    d.rectangle([40 * k, 60 * k, 216 * k, 104 * k], fill=cor)
    for x in (52, 204):
        d.rectangle([x * k - 9 * k, 60 * k, x * k + 9 * k, 206 * k], fill=cor)
    d.rectangle([30 * k, 200 * k, 226 * k, 210 * k], fill=cor)  # piso


def icone_cheio_ilha(t):
    k = t / BASE
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste(gradiente(t), (0, 0), mascara_quadrado(t, int(10 * k), int(48 * k)))
    desenho_ilha(ImageDraw.Draw(img), (255, 255, 255, 255), k)
    return img


def desenho_biblioteca(d, cor, k):
    # 4 blocos (2 x 2): a biblioteca de blocos
    for x, y in ((56, 56), (138, 56), (56, 138), (138, 138)):
        d.rounded_rectangle([x * k, y * k, (x + 62) * k, (y + 62) * k], int(10 * k), fill=cor)


def icone_contorno_biblioteca(t):
    k = t / BASE
    externo = mascara_quadrado(t, int(10 * k), int(48 * k))
    interno = mascara_quadrado(t, int(30 * k), int(32 * k))
    borda = ImageChops.subtract(externo, interno)
    simbolo = Image.new("L", (t, t), 0)
    desenho_biblioteca(ImageDraw.Draw(simbolo), 255, k)
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste((255, 255, 255, 255), (0, 0), externo)
    img.paste(gradiente(t), (0, 0), ImageChops.lighter(borda, simbolo))
    return img


def desenho_teto(d, cor, k):
    # grade de 1,00 x 1,00 vista de cima: 3 x 3 modulos, no em cada cruzamento
    linhas = (52, 102, 152, 202)
    for v in linhas:
        d.rectangle([v * k - 6 * k, 52 * k, v * k + 6 * k, 202 * k], fill=cor)
        d.rectangle([52 * k, v * k - 6 * k, 202 * k, v * k + 6 * k], fill=cor)
    for x in linhas:
        for y in linhas:
            d.rectangle([x * k - 11 * k, y * k - 11 * k, x * k + 11 * k, y * k + 11 * k], fill=cor)


def icone_cheio_teto(t):
    k = t / BASE
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste(gradiente(t), (0, 0), mascara_quadrado(t, int(10 * k), int(48 * k)))
    desenho_teto(ImageDraw.Draw(img), (255, 255, 255, 255), k)
    return img


def desenho_editar(d, cor, k):
    # lapis na diagonal: ponta embaixo/esquerda, corpo e borracha
    import math
    ux, uy = math.cos(math.radians(-45)), math.sin(math.radians(-45))
    nx, ny = -uy, ux
    px, py = 62, 194
    w = 19

    def p(s, o):
        return ((px + ux * s + nx * o) * k, (py + uy * s + ny * o) * k)

    d.polygon([p(0, 0), p(36, w), p(36, -w)], fill=cor)                    # ponta
    d.polygon([p(44, w), p(150, w), p(150, -w), p(44, -w)], fill=cor)      # corpo
    d.polygon([p(158, w), p(184, w), p(184, -w), p(158, -w)], fill=cor)    # borracha


def icone_contorno_editar(t):
    k = t / BASE
    externo = mascara_quadrado(t, int(10 * k), int(48 * k))
    interno = mascara_quadrado(t, int(30 * k), int(32 * k))
    borda = ImageChops.subtract(externo, interno)
    simbolo = Image.new("L", (t, t), 0)
    desenho_editar(ImageDraw.Draw(simbolo), 255, k)
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste((255, 255, 255, 255), (0, 0), externo)
    img.paste(gradiente(t), (0, 0), ImageChops.lighter(borda, simbolo))
    return img


def desenho_lista(d, cor, k):
    # prancheta com 4 linhas de item (marcador + linha)
    for i, y in enumerate((70, 106, 142, 178)):
        d.rectangle([62 * k, (y - 9) * k, 80 * k, (y + 9) * k], fill=cor)
        d.rectangle([94 * k, (y - 6) * k, (194 - (i % 2) * 30) * k, (y + 6) * k], fill=cor)


def icone_contorno_lista(t):
    k = t / BASE
    externo = mascara_quadrado(t, int(10 * k), int(48 * k))
    interno = mascara_quadrado(t, int(30 * k), int(32 * k))
    borda = ImageChops.subtract(externo, interno)
    simbolo = Image.new("L", (t, t), 0)
    desenho_lista(ImageDraw.Draw(simbolo), 255, k)
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste((255, 255, 255, 255), (0, 0), externo)
    img.paste(gradiente(t), (0, 0), ImageChops.lighter(borda, simbolo))
    return img


def icone_cheio(t):
    k = t / BASE
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste(gradiente(t), (0, 0), mascara_quadrado(t, int(10 * k), int(48 * k)))
    desenho_parede(ImageDraw.Draw(img), (255, 255, 255, 255), k)
    return img


def icone_contorno(t):
    k = t / BASE
    grad = gradiente(t)
    externo = mascara_quadrado(t, int(10 * k), int(48 * k))
    interno = mascara_quadrado(t, int(30 * k), int(32 * k))
    borda = ImageChops.subtract(externo, interno)
    simbolo = Image.new("L", (t, t), 0)
    desenho_porta(ImageDraw.Draw(simbolo), 255, k, 0)
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    img.paste((255, 255, 255, 255), (0, 0), externo)
    img.paste(grad, (0, 0), ImageChops.lighter(borda, simbolo))
    return img


os.makedirs(SAIDA, exist_ok=True)
for nome, fn in (("parede", icone_cheio), ("porta", icone_contorno), ("ilha", icone_cheio_ilha),
                 ("biblioteca", icone_contorno_biblioteca), ("teto", icone_cheio_teto), ("editar", icone_contorno_editar), ("lista", icone_contorno_lista)):
    grande = fn(BASE)
    for s in (16, 24, 32):
        grande.resize((s, s), Image.LANCZOS).save(os.path.join(SAIDA, f"{nome}_{s}.png"))
    grande.resize((128, 128), Image.LANCZOS).save(os.path.join(SAIDA, f"{nome}_128.png"))
print("icones gerados em", SAIDA)
