#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
STAND1 Octanorm - empacota o .rbz e atualiza o latest.json (mesmo esquema do Concha Render).
Uso:  python build.py            (le a versao do STAND1_Octanorm_loader.rb)
Faz:  roda os testes, gera STAND1_Octanorm.rbz (o que o auto-update baixa) e uma
      copia STAND1_Octanorm_vX.rbz em versoes_anteriores, calcula o sha256 e
      reescreve o latest.json. Barras normais no zip (o instalador exige).
Depois: escrever as notas no latest.json, commitar e dar push.
"""
import hashlib, io, json, os, re, shutil, subprocess, sys, zipfile

RAIZ = os.path.dirname(os.path.abspath(__file__))
FONTE = os.path.join(RAIZ, 'STAND1_Octanorm')
LOADER = os.path.join(RAIZ, 'STAND1_Octanorm_loader.rb')
RBZ = os.path.join(RAIZ, 'STAND1_Octanorm.rbz')
USUARIO, REPO = 'ggabrielmorais-afk', 'stand1-octanorm'


def versao():
    s = io.open(LOADER, encoding='utf-8').read()
    v = re.search(r"version\s*=\s*'([\d.]+)'", s)
    c = re.search(r"VERSAO\s*=\s*'([\d.]+)'", s)
    if not v or not c or v.group(1) != c.group(1):
        sys.exit('VERSAO e version do loader precisam ser iguais')
    return v.group(1)


def testes():
    for nome in ('test_layout.rb', 'test_autoupdate.rb', 'test_biblioteca.rb'):
        r = subprocess.run(['ruby', os.path.join('tests', nome)], cwd=FONTE, capture_output=True, text=True)
        if r.returncode != 0 or ' 0 failures, 0 errors' not in r.stdout:
            print(r.stdout[-2000:]); print(r.stderr[-1000:])
            sys.exit('TESTES FALHARAM (%s) - build abortado' % nome)
    print('  testes verdes')


def empacotar():
    with zipfile.ZipFile(RBZ, 'w', zipfile.ZIP_DEFLATED) as z:
        z.write(LOADER, 'STAND1_Octanorm_loader.rb')
        for atual, dirs, arqs in os.walk(FONTE):
            dirs[:] = sorted(d for d in dirs if d not in ('tests', '__pycache__'))
            for a in sorted(arqs):
                p = os.path.join(atual, a)
                z.write(p, os.path.relpath(p, RAIZ).replace('\\', '/'))
    return hashlib.sha256(open(RBZ, 'rb').read()).hexdigest()


def main():
    v = versao()
    print('STAND1 Octanorm %s' % v)
    testes()
    sha = empacotar()
    os.makedirs(os.path.join(RAIZ, 'versoes_anteriores'), exist_ok=True)
    shutil.copyfile(RBZ, os.path.join(RAIZ, 'versoes_anteriores', 'STAND1_Octanorm_v%s.rbz' % v))
    print('  %s  %d bytes  sha256 %s' % (os.path.basename(RBZ), os.path.getsize(RBZ), sha))
    caminho = os.path.join(RAIZ, 'latest.json')
    m = json.load(io.open(caminho, encoding='utf-8')) if os.path.exists(caminho) else {}
    m['versao'] = v
    m['rbz'] = 'https://raw.githubusercontent.com/%s/%s/main/STAND1_Octanorm.rbz' % (USUARIO, REPO)
    m['sha256'] = sha
    m.setdefault('notas', '')
    io.open(caminho, 'w', encoding='utf-8').write(json.dumps(m, ensure_ascii=False, indent=4) + '\n')
    print('  latest.json atualizado')
    print('\nFalta: escrever as notas no latest.json, commitar e dar push.')


if __name__ == '__main__':
    main()
