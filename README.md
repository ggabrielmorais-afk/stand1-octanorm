# STAND1 Octanorm

Plugin SketchUp da **Stand1 Produções** para desenhar paredes, salas e testeiras de
ilha em Octanorm clicando os pontos no piso. Cada trecho já sai na tag
**ESTRUTURAS** com "Parede" ou "Testeira" no nome, então o **STAND1_Memorial**
conta o m² sem ninguém etiquetar nada.

Feito por Gabriel com Claude em out/2026, a partir dos blocos da Stand1
(`CATALOGO STAND1\PLuguin`). Atualização automática pelo mesmo esquema do EVA e
do Memorial.

---

## Botões (barra "STAND1 Octanorm")

| Botão | O que faz |
|---|---|
| **Parede / sala** | Parede de 2,20 ou 2,90 (com testeira), em TS ou vidro, com porta opcional |
| **Testeira (ilha)** | Só a faixa de 2,20 a 2,90, em TS, vidro ou MDF. Montante de canto e de ponta desce até o chão |
| **Teto grid Z500 (pergolado)** | Grade de 1,00 × 1,00 m em Z500. Com sala, ilha ou parede em L selecionada, monta em cima dela. Sem seleção, marca 2 cantos ou digita a medida (ex.: 4x3) |
| **Mover porta** | Clica num vão de 1,00 m e a porta vai pra lá. Clicar no vão da porta tira a porta |
| **Editar** | Seleciona parede, sala, ilha ou teto pronto e troca medida, testeira, fechamento ou porta. Também no botão direito |
| **Lista de peças** | Conta montante, travessa, Z500, folha TS, vidro, placa MDF, spider e porta da seleção (ou do modelo inteiro) e salva planilha |
| **Biblioteca Stand1** | Janela com os blocos do catálogo (categoria, busca, miniatura). Um clique põe o bloco no modelo. **+ Adicionar bloco** salva o que estiver selecionado como bloco novo, com o nome de quem adicionou |

Durante o desenho:
- **clique** adiciona ponto;
- **F** ou clicar no 1º ponto **fecha a sala**;
- **Enter** ou duplo clique termina uma parede aberta;
- **Backspace** desfaz o último ponto;
- **Shift** trava no eixo;
- digitar a medida crava o trecho. **Número sozinho é metro** ("3" = 3,00 m), e também aceita "300cm".

O cursor gruda nos montantes das paredes que já existem (ímã rosa) e desliza ao
longo delas. A parede nova usa o mesmo montante, sem duplicar.

---

## Regras de montagem (lidas dos blocos da Stand1)

**Modulação:** 1,00 m de eixo a eixo. Uma sobra de ~0,50 m (0,45 a 0,55) vira módulo de 0,50 (folha TS 0,50 e vidro 0,49). O que sobrar fora disso vira folha especial e aparece no relatório.

**Parede TS:** Travesa no pé, folha TS de 0,46 cm no meio do perfil, Travesa no topo (2,20).
Testeira TS: folha + Travesa em cima (2,90).

**Parede de vidro:**
- placa de 99,56 cm, 3 cm à frente do eixo do montante;
- de baixo pra cima: 1,07 + 1,10 (até 2,20) + 0,70 na testeira de vidro (2,90);
- spider montado pelos 4 braços do `Spider.skp`, **só do lado que tem vidro**. Isso vale nas pontas, nos cantos e ao lado da porta;
- Travesa no pé e Z500 no topo da testeira, atrás do vidro.

**Testeira de ilha:**
- faixa de 2,20 a 2,90;
- TS: igual à testeira TS;
- vidro e MDF (branco): igual à testeira de vidro, com placa na frente, Z500 e spider;
- montantes de canto e de ponta vão até o chão, e os do meio ficam só na faixa.

**Lado de fora:** vidro e MDF vão do lado de fora da sala em qualquer sentido de desenho (sala horária é espelhada). Na parede em L, "dentro" é o lado do canto.

**Alumínio:** material cinza das peças fica com B = 80 no HSB ao carregar a peça.

**Portas:** `Porta Octanorm.skp` (TS) e `Porta de vidro.skp`, só em vão de 1,00 m.
Na parede de vidro a porta abre o vão até 2,20, e a placa de 0,70 da testeira fica em cima.

**Memorial (desde a 1.4.0):**
- Nome na sequência da Stand1, sem medida: "Parede em perfil de alumínio com fechamento em TS / vidro / MDF", "Testeira em perfil...", "Teto em perfil de alumínio Z500", "Forro em eucatex".
- Sala fechada = 1 item com o nome do ambiente (Sala / Depósito / Copa / Cabine + complemento). Um componente só com pontos-guia mede a planta (X × Y) e a altura, e o Memorial calcula 2 × (X + Y) × altura. As paredes da sala ficam sem tag.
- Parede com testeira = 1 item de 2,90 por trecho. Testeira sozinha (ilha) = item próprio.
- Portas e peças (montante, travessa, spider) nunca contam.
- Componentes diferentes com o mesmo nome ganham "#1" no SketchUp. O patch do Memorial em `patch_memorial_tatas/` tira o "#1" na contagem.

**Memorial (até a 1.3):**
- Cada trecho reto é **um componente** na tag ESTRUTURAS. Os nomes seguem estes formatos:
  - "Parede octanorm TS 3,00 x 2,20 m"
  - "Parede de vidro octanorm ..."
  - "Testeira octanorm ...", "Testeira MDF ...", "Testeira de vidro octanorm ..."
- Montantes e spiders ficam **fora** desse componente e sem tag.
- Dois pontos-guia marcam 0 e o comprimento, pra caixa medir **eixo a eixo** (3,00 × 2,20 = 6,60 m²).
- As portas entram como item próprio: "Porta Octanorm" e "Porta de vidro".

**Teto grid Z500:**
- grade de 1,00 × 1,00 m, com meio módulo de 0,50 quando sobra (mesma conta da parede);
- Z500 (17,5 cm de altura) entre os nós, com o topo em 2,90 ou 2,20, e um pedaço de montante de 17,5 cm em cada nó;
- lado em cima de parede da mesma altura não leva viga nem nó, porque o topo da parede fecha a borda e os montantes dela seguram as vigas;
- canto que não encosta em parede leva montante até o chão (teto solto = 4 montantes);
- o relatório avisa ponta de viga que cai em cima de parede sem montante embaixo. Isso acontece em sala de 4,50, porque a parede oposta é desenhada no sentido contrário e o meio módulo dela fica na outra ponta;
- Memorial: um componente "Teto grid Z500 4,00 x 3,00 m" na tag ESTRUTURAS, só com as vigas. A viga da borda entra meia espessura e os pontos-guia marcam os cantos, então a caixa mede L × P exato. Nós e montantes ficam fora, sem tag.

**Editar:**
- parede aberta: medida de cada trecho, separada por ponto e vírgula ("3; 2,5"). Mantém o ponto inicial e as direções;
- sala retangular e ilha: L × P, mantendo o 1º canto. Sala de outro formato só troca as opções;
- teto: L × P e altura. Os lados em cima de parede e os montantes até o chão são recalculados com o que está no modelo na hora;
- a porta fica no mesmo vão se ele ainda existir. Senão vai pro último vão de 1,00 m;
- medida igual à que já estava não mexe nos pontos;
- cópia de sala feita com Ctrl no Mover: editar uma não muda a outra.

**Refazer:** cada parede guarda nos atributos (`stand1_octanorm`) os pontos, as opções e a posição da porta, e cada teto guarda canto, ângulo, L, P e altura. É isso que permite o Editar, o Mover porta e o ímã.

---

## Biblioteca Stand1

- Lê a pasta do catálogo (padrão `Documents\GABRIEL EMPRESA\Gabriel Stand 1\CATALOGO STAND1`, mas pode ser uma pasta do Google Drive compartilhada com a equipe). Cada máquina escolhe a sua em **Trocar pasta**, e a escolha fica salva.
- Usa `catalogo.json` e `_previas/mini/*.jpg` da própria pasta. Esses arquivos são gerados por `gerar_indice.py`, que fica com o Gabriel e roda de novo sempre que entra ou sai bloco oficial.
- Bloco na pasta que está fora do índice aparece em "Outros", sem miniatura.
- Inserir = `definitions.load` + `place_component`. O componente de dentro do bloco já vem na tag do Memorial.

**+ Adicionar bloco (desde a 1.5.0):**
- Na primeira vez, pergunta o nome da pessoa (fica salvo nesta máquina e é reaproveitado depois). O nome aparece no cartão dos outros ("por Fulano"); no seu próprio, aparece "seu".
- Cada pessoa grava num arquivo próprio, `meus_blocos_<nome>.json` (o antigo `meus_blocos.json` continua sendo lido, por compatibilidade). Isso evita que duas pessoas adicionando bloco ao mesmo tempo numa pasta do Drive disputem a mesma gravação — o Drive sincroniza arquivos diferentes sem conflito.
- Alguns segundos depois de abrir o SketchUp, `Biblioteca.verificar_novidades` confere o que a equipe adicionou desde a última vez que **esta máquina** checou (guardado em `ultima_visita_blocos`) e avisa num popup (nome de quem adicionou + bloco + categoria). Não avisa sobre o que a própria pessoa adicionou. Primeira vez nunca avisa nada — só estabelece a base.
- Timestamp com milissegundo (`Biblioteca.agora`): segundo sozinho colide fácil quando duas gravações acontecem perto uma da outra.

**Versão (desde a 1.5.1):** o rodapé mostra a versão instalada ("v1.5.1") e tem um botão **Verificar atualização** (chama `AutoUpdate.check(true)`, mesma checagem do menu Extensões). Foi pra cá porque a confusão de versão (alguém testando uma versão velha sem saber) costuma aparecer justamente nesta janela.

## Estrutura

```
STAND1_Octanorm/
  STAND1_Octanorm_loader.rb   registra a extensão (versão fica aqui)
  STAND1_Octanorm/
    core.rb         menu, barra, janelas de opção, relatório
    layout.rb       cálculo puro (sem SketchUp): módulos, trechos, ímã, porta, medida
    geometria.rb    monta as peças no modelo
    ferramenta.rb   ferramenta de clique (orto, ímã, F, Backspace, medida em metros)
    porta.rb        ferramenta Mover porta
    teto.rb         teto grid Z500 (da sala selecionada ou com 2 cliques)
    editar.rb       Editar: refaz parede, sala, ilha ou teto a partir dos atributos
    contagem.rb     Lista de peças (html/pecas.html)
    autoupdate.rb   checa latest.json no GitHub e instala o .rbz
    biblioteca.rb   janela Biblioteca Stand1 (html/biblioteca.html)
    pecas/          Octanorm, Travesa, Z500, Spider, Porta Octanorm, Porta de vidro (.skp)
    icons/          16/24/32/128 px, paleta do EVA/Memorial
    tests/          ruby tests/test_layout.rb  (não vai pro .rbz)
  ferramentas/      scripts de apoio (ler e desmontar blocos, gerar ícones) + leituras .json
  build.ps1         gera STAND1_Octanorm_vX.rbz e arquiva o anterior
  latest.json       manifesto da atualização automática
  versoes_anteriores/
```

---

## Soltar versão

Desde a 1.4.0 a atualização vem do GitHub do Gabriel: `ggabrielmorais-afk/stand1-octanorm` (público).

1. Subir a versão em `STAND1_Octanorm_loader.rb` (as **duas** linhas: `VERSAO` e `version`).
2. `python build.py`: roda os testes, gera `STAND1_Octanorm.rbz`, guarda a cópia em `versoes_anteriores` e grava versão, link e sha256 no `latest.json`.
3. Escrever as `notas` no `latest.json`, commitar e dar push. Sem rodar o build.py o sha256 não confere e ninguém atualiza.

### Antes da 1.4.0 (build.ps1, GitHub do Tatas)

1. Subir a versão em `STAND1_Octanorm_loader.rb` (as **duas** linhas: `VERSAO` e `version`).
2. Rodar os testes: `ruby STAND1_Octanorm/tests/test_layout.rb`.
3. Rodar `powershell -ExecutionPolicy Bypass -File build.ps1`.
4. Atualizar `latest.json`: `versao`, link do `rbz` e `notas`.
5. Commit + push. A equipe recebe a pergunta "Instalar agora?" na próxima vez que abrir o SketchUp.

O repositório precisa continuar **público**, senão o `raw.githubusercontent.com` pede token e a atualização para.

---

## Pendente / não confirmado

- Não testado por ninguém além do Gabriel. Testar em mais de uma máquina antes de liberar pra toda a equipe.
- Coluna de vidro de 0,49: hoje empilha 1,07 + 1,10 (+ 0,70) igual à de 1 m. Falta confirmar quais placas de 0,49 vão.
- Canto da sala de vidro: as placas podem cruzar ou deixar uma fresta pequena na esquina, e o miolo do spider pode aparecer duplicado.
- Placa de MDF da ilha está com a espessura do vidro (1,22 cm).
- Teto: o nó é um pedaço de montante de 17,5 cm. Falta confirmar se na montagem real o cruzamento das Z500 usa outra peça.
- Teto solto tem montante só nos 4 cantos. Falta a regra de vão máximo da Z500 pra pôr montante no meio.
- Sala de 4,50: o meio módulo da parede oposta fica na outra ponta, e as vigas do teto não caem em montante desse lado (o relatório avisa).
- Dois componentes diferentes com o mesmo nome ganham "#1" no fim (ex.: parede com e sem porta, teto com e sem lado em parede). O Memorial lista as duas linhas separadas.
- Ideias anotadas: lista de peças pra montagem e orçamento, trecho travado em múltiplos de 1 m.
