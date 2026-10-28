# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — core.rb
# Menu, botoes, opcoes e relatorio.
# =============================================================================
require 'sketchup'
require_relative 'layout'
require_relative 'geometria'
require_relative 'ferramenta'
require_relative 'porta'
require_relative 'teto'
require_relative 'editar'
require_relative 'contagem'
require_relative 'autoupdate'
require_relative 'biblioteca'

module STAND1
  module Octanorm
    # Octanorm Stand1: parede 2,20; com testeira 0,70 em cima = 2,90. Nao existe 2,70.
    ALTURA_PAREDE = 220.0
    FECHAMENTO_OPCOES = { "TS branco" => :ts, "Vidro" => :vidro, "So estrutura" => :estrutura }.freeze
    PORTA_OPCOES = { "Nenhuma" => :nenhuma, "Octanorm (no ultimo vao)" => :octanorm,
                     "Vidro (no ultimo vao)" => :vidro }.freeze

    # padrao Stand1: 2,20 + testeira 0,70 = 2,90, com travessa nos 2,20
    @ultimas = ["Sim (2,90)", "TS branco", "Nenhuma"]

    def self.perguntar_opcoes
      r = UI.inputbox(["Testeira 0,70 em cima", "Fechamento", "Porta"],
                      @ultimas,
                      ["Sim (2,90)|Nao (2,20)", FECHAMENTO_OPCOES.keys.join("|"), PORTA_OPCOES.keys.join("|")],
                      "STAND1 Octanorm")
      return nil unless r

      @ultimas = r
      { altura: ALTURA_PAREDE, testeira: r[0].start_with?("Sim"), fechamento: FECHAMENTO_OPCOES[r[1]],
        porta: PORTA_OPCOES[r[2]] }
    end

    def self.desenhar
      opcoes = perguntar_opcoes
      return unless opcoes

      Sketchup.active_model.select_tool(Ferramenta.new(opcoes))
    end

    ILHA_OPCOES = { "TS" => :ts, "Vidro" => :vidro, "MDF" => :mdf }.freeze
    @ultima_ilha = ["TS"]

    # Testeira de ilha: so a faixa 2,20..2,90; montantes de canto e ponta descem
    # ate o chao (sustentam), os do meio ficam so na faixa.
    def self.desenhar_ilha
      r = UI.inputbox(["Testeira (ilha) em"], @ultima_ilha, [ILHA_OPCOES.keys.join("|")],
                      "STAND1 Octanorm: testeira de ilha")
      return unless r

      @ultima_ilha = r
      opcoes = { altura: ALTURA_PAREDE, testeira: true, fechamento: ILHA_OPCOES[r[0]], porta: :nenhuma,
                 so_testeira: true }
      Sketchup.active_model.select_tool(Ferramenta.new(opcoes))
    end

    def self.mover_porta_ferramenta
      Sketchup.active_model.select_tool(FerramentaPorta.new)
    end

    @ultima_teto = [Teto::ALTURAS.keys.first, Teto::FORROS.keys.first]

    # Teto grid Z500. Com sala, ilha ou parede em L selecionada: monta em cima
    # dela, na altura dela. Sem nada selecionado: retangulo com 2 cliques.
    def self.desenhar_teto
      model = Sketchup.active_model
      sala = Editar.grupo(model)
      sala = nil unless sala && sala.get_attribute(Geometria::ATRIB, "pontos")
      unless sala
        r = UI.inputbox(["Topo do teto", "Fechar o teto com"], @ultima_teto,
                        [Teto::ALTURAS.keys.join("|"), Teto::FORROS.keys.join("|")], "STAND1 Octanorm: teto grid Z500")
        return unless r

        @ultima_teto = r
        model.select_tool(FerramentaTeto.new(altura: Teto::ALTURAS[r[0]], forro: Teto::FORROS[r[1]]))
        return
      end

      # em cima da sala a altura vem dela: so pergunta o forro
      r = UI.inputbox(["Fechar o teto com"], [@ultima_teto[1]], [Teto::FORROS.keys.join("|")], "STAND1 Octanorm: teto grid Z500")
      return unless r

      @ultima_teto[1] = r[0]
      Editar.sair_de(model, sala)
      model.start_operation("STAND1 Octanorm: teto grid Z500", true)
      begin
        g = Teto.construir_da_sala(model, sala, forro: Teto::FORROS[r[0]])
        model.commit_operation
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Nao deu pra montar o teto:\n#{e.message}\n\nParede reta nao vira teto: selecione sala, ilha " \
                      "ou parede em L, ou desenhe o teto com 2 cliques sem nada selecionado.")
        return
      end
      model.selection.clear
      model.selection.add(g)
      Teto.relatorio(g)
    end

    def self.relatorio_ilha(trechos)
      r = Layout.resumo(trechos, 70.0)
      ml = trechos.sum { |t| t[:comprimento] } / 100.0
      txt = "Testeira de ilha: #{trechos.size} trecho(s)\n\n"
      txt << "Testeira: #{Layout.fmt(ml.round(2))} m lineares (#{Layout.fmt(r[:m2])} m2)\n"
      txt << "Modulos de 1,00 m: #{r[:folhas_normais]}\n"
      txt << "Modulos de 0,50 m: #{r[:folhas_meio]}\n" if r[:folhas_meio] > 0
      txt << "Montantes ate o chao (cantos e pontas): #{Layout.apoios_ate_chao(trechos).size}\n"
      txt << "\nAtencao:\n- " + r[:avisos].join("\n- ") if r[:avisos].any?
      UI.messagebox(txt)
    end

    def self.relatorio(trechos, opcoes)
      return relatorio_ilha(trechos) if opcoes[:so_testeira]

      r = Layout.resumo(trechos, opcoes[:altura])
      txt = "Parede montada: #{trechos.size} trecho(s)\n\n"
      txt << "Folhas de 1,00 m: #{r[:folhas_normais]}\n"
      txt << "Modulos de 0,50 m: #{r[:folhas_meio]}\n" if r[:folhas_meio] > 0
      txt << "Folhas especiais: #{r[:folhas_especiais]}\n"
      txt << "Area de parede: #{Layout.fmt(r[:m2])} m2\n"
      if opcoes[:testeira]
        ml = trechos.sum { |t| t[:comprimento] } / 100.0
        txt << "Testeira: #{Layout.fmt(ml.round(2))} m lineares\n"
      end
      if opcoes[:porta] && opcoes[:porta] != :nenhuma
        pos = opcoes[:porta_pos] || Layout.porta_padrao(trechos)
        txt << (pos ? "Porta: trecho #{pos[:trecho] + 1}, vao #{pos[:vao] + 1} (botao Mover porta troca de lugar)\n" :
                      "Porta: nao coube (nenhum vao de 1,00 m)\n")
      end
      txt << "\nAtencao:\n- " + r[:avisos].join("\n- ") if r[:avisos].any?
      UI.messagebox(txt)
    end

    unless file_loaded?(__FILE__)
      icones = File.join(File.dirname(__FILE__), "icons")

      cmd = UI::Command.new("Parede / sala Octanorm") { desenhar }
      cmd.small_icon = File.join(icones, "parede_16.png")
      cmd.large_icon = File.join(icones, "parede_32.png")
      cmd.tooltip = "STAND1 Octanorm: desenhar parede / sala"
      cmd.status_bar_text = "Clique os pontos no piso; a parede de Octanorm e montada sozinha."

      cmd_p = UI::Command.new("Mover porta") { mover_porta_ferramenta }
      cmd_p.small_icon = File.join(icones, "porta_16.png")
      cmd_p.large_icon = File.join(icones, "porta_32.png")
      cmd_p.tooltip = "STAND1 Octanorm: mover / por / tirar porta"
      cmd_p.status_bar_text = "Clique no vao da parede onde a porta deve ficar."

      cmd_b = UI::Command.new("Biblioteca Stand1") { Biblioteca.abrir }
      cmd_b.small_icon = File.join(icones, "biblioteca_16.png")
      cmd_b.large_icon = File.join(icones, "biblioteca_32.png")
      cmd_b.tooltip = "Biblioteca Stand1: blocos do catalogo com busca e categoria"
      cmd_b.status_bar_text = "Clique no bloco e posicione no modelo."

      cmd_i = UI::Command.new("Testeira (ilha)") { desenhar_ilha }
      cmd_i.small_icon = File.join(icones, "ilha_16.png")
      cmd_i.large_icon = File.join(icones, "ilha_32.png")
      cmd_i.tooltip = "STAND1 Octanorm: testeira de ilha (so a testeira; montantes de canto e ponta ate o chao)"
      cmd_i.status_bar_text = "Clique os pontos da testeira. TS, vidro ou MDF."

      cmd_t = UI::Command.new("Teto grid Z500 (pergolado)") { desenhar_teto }
      cmd_t.small_icon = File.join(icones, "teto_16.png")
      cmd_t.large_icon = File.join(icones, "teto_32.png")
      cmd_t.tooltip = "STAND1 Octanorm: teto grid Z500 de 1,00 x 1,00 m (sala selecionada ou 2 cliques)"
      cmd_t.status_bar_text = "Selecione a sala e clique, ou clique sem selecao e marque 2 cantos."

      cmd_e = UI::Command.new("Editar") { Editar.executar }
      cmd_e.small_icon = File.join(icones, "editar_16.png")
      cmd_e.large_icon = File.join(icones, "editar_32.png")
      cmd_e.tooltip = "STAND1 Octanorm: editar parede, sala, ilha ou teto pronto"
      cmd_e.status_bar_text = "Selecione o que foi feito pelo plugin e troque medida, testeira, fechamento ou porta."

      cmd_l = UI::Command.new("Lista de pecas") { Contagem.abrir }
      cmd_l.small_icon = File.join(icones, "lista_16.png")
      cmd_l.large_icon = File.join(icones, "lista_32.png")
      cmd_l.tooltip = "STAND1 Octanorm: lista de pecas (montante, travessa, folha, vidro, spider, Z500, porta)"
      cmd_l.status_bar_text = "Conta o que estiver selecionado, ou o modelo inteiro sem selecao."

      menu = UI.menu("Extensions").add_submenu("STAND1 Octanorm")
      menu.add_item(cmd)
      menu.add_item(cmd_i)
      menu.add_item(cmd_t)
      menu.add_item(cmd_p)
      menu.add_item(cmd_e)
      menu.add_item(cmd_l)
      menu.add_item(cmd_b)

      barra = UI::Toolbar.new("STAND1 Octanorm")
      barra.add_item(cmd)
      barra.add_item(cmd_i)
      barra.add_item(cmd_t)
      barra.add_item(cmd_p)
      barra.add_item(cmd_e)
      barra.add_item(cmd_l)
      barra.add_item(cmd_b)

      # botao direito em cima de algo feito pelo plugin
      UI.add_context_menu_handler do |m|
        g = Editar.grupo(Sketchup.active_model)
        next unless g

        teto = g.get_attribute(Geometria::ATRIB, "tipo") == "teto"
        sub = m.add_submenu("STAND1 Octanorm")
        sub.add_item(teto ? "Editar teto" : "Editar") { Editar.executar }
        sub.add_item("Teto grid Z500 em cima") { desenhar_teto } unless teto
      end
      # sempre mostra a barra ao abrir (na v0.4 ela sumia depois de atualizar)
      UI.start_timer(1.0, false) { barra.show }
      menu.add_separator
      menu.add_item("Mostrar barra de botoes") { barra.show }
      menu.add_item("Verificar atualizacao") { AutoUpdate.check(true) }
      # checa o repo do Gabriel sozinho, alguns segundos depois de abrir o SketchUp
      UI.start_timer(5.0, false) { AutoUpdate.check(false) } rescue nil
      # avisa o que a equipe adicionou na Biblioteca desde a ultima vez (pasta compartilhada)
      UI.start_timer(7.0, false) { Biblioteca.verificar_novidades } rescue nil
      puts "STAND1 Octanorm #{VERSAO} carregado"
      file_loaded(__FILE__)
    end
  end
end
