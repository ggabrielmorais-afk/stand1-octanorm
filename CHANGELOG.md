# Histórico STAND1 Octanorm

## 1.5.1 — 28/10/2026
- **Botão "Verificar atualização" dentro da Biblioteca Stand1** (antes só existia em Extensões → STAND1 Octanorm). O rodapé da janela também mostra a versão instalada ("v1.5.1"), pra não ter mais dúvida de qual versão cada máquina está rodando.

## 1.5.0 — 28/10/2026
- **Biblioteca em pasta compartilhada (Drive).** "+ Adicionar bloco" agora pergunta o nome de quem está adicionando (lembra pra próxima vez) e mostra "por Fulano" no cartão de quem não é você. Cada pessoa grava num arquivo próprio (`meus_blocos_<nome>.json`): duas pessoas adicionando bloco ao mesmo tempo numa pasta do Drive não disputam a mesma gravação.
- **Aviso de bloco novo.** Alguns segundos depois de abrir o SketchUp, se um colega adicionou bloco à Biblioteca desde a última vez que esta máquina checou, aparece um aviso com quem adicionou, o nome do bloco e a categoria.

## 1.4.1 — 27/10/2026
- **Meio módulo do mesmo lado nas paredes opostas.** Antes ele ia sempre no fim de cada parede, e numa sala desenhada em volta a parede de cima ficava com a sobra no canto oposto ao da de baixo. Agora a sobra fica sempre do mesmo lado da sala, os montantes das paredes opostas casam e as vigas do teto caem em montante (sala de 4,50: de 4 pontas sem montante pra 0). Parede reta não muda.
- Sala ou parede antiga que tinha porta numa parede que mudou de lado pode ter a porta deslocada meio módulo ao usar o Editar. Confira com o Mover porta.

## 1.4.0 — 27/10/2026
- **Memorial mais limpo.** Os nomes seguem a sequência da Stand1: "Parede em perfil de alumínio com fechamento em TS", "Testeira em perfil de alumínio com fechamento em vidro". A medida sai do nome porque o Memorial já mostra.
  - **Sala fechada vira um item só.** Ao fechar, o plugin pergunta o tipo (Sala / Depósito / Copa / Cabine) e um complemento, e o Memorial mede como recinto: 2 × (X + Y) × altura. Ex.: "Depósito de apoio em perfil de alumínio com fechamento em TS (4,00 × 4,00 × 2,90) - 46,40 m²". O Editar troca o nome.
  - Parede com testeira conta como uma parede de 2,90. Testeira só vira item próprio quando vem sozinha (ilha).
  - Porta (Octanorm ou vidro) não aparece mais no Memorial.
- **Teto com forro eucatex:** opção "Fechar o teto com" no botão Teto e no Editar. Placa por módulo em cima da grade. No Memorial é item próprio: "Forro em eucatex", L × P. Conta na Lista de peças.
- **Atualização automática pelo GitHub do Gabriel** (`ggabrielmorais-afk/stand1-octanorm`). Só instala o .rbz do próprio repositório com o sha256 conferido, mesmo esquema do Concha Render. `build.py` gera o pacote e o latest.json (substitui o build.ps1).

## 1.3.0 — 27/10/2026
- **Vidro e MDF sempre pro lado de fora.** Antes, sala desenhada no sentido horário ficava com a placa pra dentro. Agora o plugin vê o sentido do desenho e espelha a parede quando precisa (sala, ilha e parede em L). Parede pronta corrige ao usar o Editar.
- **Alumínio mais claro:** material cinza das peças (montante, travessa, Z500, spider, porta) com B = 80 no HSB.
- Botão **Lista de peças**: conta montante (por altura), travessa e Z500 (por vão), folha TS, vidro e placa MDF (por medida), spider (1, 2, 3 ou 4 garras) e porta. Conta a seleção ou o modelo inteiro e salva planilha (CSV) ou copia.
- Spider passa a ser um grupo por nó ("Spider 4 garras"), pra a lista contar a peça inteira.
- **Biblioteca: + Adicionar bloco.** Salva o grupo/componente selecionado como bloco do catálogo: um componente na tag do Memorial, origem no canto, miniatura e categoria. Fica só na máquina de quem adicionou, com índice próprio em `meus_blocos.json` (catálogo novo não apaga). Selo "seu" no cartão.
- **Modo noturno** na Biblioteca e na Lista de peças (botão da lua, lembra a escolha).

## 1.2.0 — 27/10/2026
- Botão **Teto grid Z500 (pergolado)**: grade de módulos 1,00 × 1,00 m (meio módulo de 0,50 quando sobra), Z500 entre os nós e um pedaço de montante em cada nó.
  - Com sala, ilha ou parede em L selecionada, monta em cima dela na altura dela (2,20 ou 2,90).
  - Sem nada selecionado, pergunta a altura e marca o retângulo com 2 cliques ou digitando a medida (ex.: 4x3). Gruda nos montantes como a parede.
  - Lado em cima de parede da mesma altura não leva viga nem nó, porque o topo da parede já fecha a borda. Canto que não encosta em parede leva montante até o chão.
  - Relatório avisa ponta de viga em cima de parede sem montante embaixo (ex.: sala de 4,50 com o meio módulo em pontas diferentes).
  - Memorial: um componente "Teto grid Z500 L x P m" na tag ESTRUTURAS, com a caixa medindo L × P exato. Nós e montantes ficam fora dele, sem tag.
- Botão **Editar**: seleciona parede, sala, ilha ou teto pronto e troca medida, testeira, fechamento ou porta. Refaz no mesmo lugar, mesmo se o grupo foi movido ou girado.
  - Parede aberta: medida de cada trecho ("3; 2,5"). Sala retangular e ilha: L × P. Teto: L × P e altura.
  - Porta fica no mesmo vão se ele ainda existir.
  - Também no botão direito: "STAND1 Octanorm > Editar" e "Teto grid Z500 em cima".
- Editar ou mover a porta de uma **cópia** de sala não mexe mais na original.
- Relatório da parede diz em qual trecho e vão a porta ficou.

## 1.1.1
- Biblioteca: categoria **Stands prontos** (estandes completos tirados do FLASO, em `CATALOGO STAND1/STANDS PRONTOS`) e suporte a bloco em subpasta do catálogo.

## 1.1.0 — 26/10/2026
- Botão **Biblioteca Stand1**: janela com os blocos de `CATALOGO STAND1` por categoria, busca sem acento e miniatura. Um clique põe o bloco na mão pra posicionar.
- Lê `catalogo.json` + `_previas/mini/` da pasta do catálogo (gerados por `stand1-catalogo/gerar_indice.py`). A pasta é escolhida em "Trocar pasta" e fica salva.

## 1.0.0 — 26/10/2026
Primeira versão no GitHub da Stand1, no padrão do EVA (loader + pasta + build.ps1 + latest.json).
- Atualização automática: checa `latest.json` ao abrir o SketchUp e pergunta "Instalar agora?". Menu "Verificar atualizacao".
- Nome dos arquivos mudou para `STAND1_Octanorm_loader.rb` / `STAND1_Octanorm/`. **Quem tem a 0.x precisa desinstalar antes.**

## 0.10.1
- Testeira de ilha em MDF segue a lógica do vidro (placa na frente, spider, Z500), em branco.

## 0.10.0
- Botão "Testeira (ilha)": só a faixa 2,20 a 2,90 em TS, vidro ou MDF. Canto e ponta descem até o chão.

## 0.9.0
- Spider só do lado que tem vidro (pontas, cantos, ao lado da porta), montado pelos braços do Spider.
- Vidro de cima 0,70. Folha de 0,50 também no TS.

## 0.8.0
- Ímã mais forte: raio maior, desliza ao longo da parede, acha parede dentro de grupo.
- Módulo de 0,50 no vidro (placa 0,49).

## 0.7.0 / 0.7.1
- Medida em metros, F fecha a sala, Backspace desfaz, menu no botão direito.
- Ícones e cores na paleta do EVA / Memorial.

## 0.6.0
- Parede de vidro seguindo o bloco da Stand1 (placas, spiders, Z500) e porta de vidro.

## 0.5.0
- Altura só 2,20 ou 2,90. Topo em Travesa. Ímã nos montantes existentes. Barra sempre visível.

## 0.4.0
- Porta Octanorm no último vão e botão Mover porta.

## 0.1.0 a 0.3.0
- Protótipo: desenho por cliques, peças reais (montante, Travesa), orto, m² exato no Memorial.
