# encoding: UTF-8
# =============================================================================
# STAND1 Octanorm — janela.rb
# Ferramenta "Janela de vidro": clica nos modulos de uma parede TS feita pelo
# plugin e eles ganham vidro de 1,00 ate 2,20 (TS embaixo, testeira TS em cima).
# Clicar de novo no modulo tira o vidro. Fica ativa ate o Esc.
# Referencia: Cozinha Show do Salon du Chocolat (projeto do Tatas), 11/11/2026.
# =============================================================================
require 'json'

module STAND1
  module Octanorm
    class FerramentaJanela < FerramentaPorta
      def activate
        @ip = Sketchup::InputPoint.new
        Sketchup.status_text = "Janela de vidro: clique nos modulos da parede TS que ganham vidro de 1,00 a 2,20. " \
                               "Clique de novo pra tirar. Esc sai."
      end

      def onLButtonDown(_flags, x, y, view)
        @ip.pick(view, x, y)
        grupo, tr = parede_sob_cursor(view, x, y)
        unless grupo
          UI.beep
          Sketchup.status_text = "Clique em cima de uma parede TS feita pelo STAND1 Octanorm."
          return
        end
        local = @ip.position.transform(tr.inverse)
        Octanorm.alternar_janela(grupo, local.x.to_cm, local.y.to_cm)
        view.invalidate
      end
    end

    # Le os atributos da parede, liga/desliga a janela no modulo clicado e refaz.
    # Devolve a lista nova de janelas (nil se nao deu).
    def self.alternar_janela(grupo, x_cm, y_cm)
      a = ->(k) { grupo.get_attribute(Geometria::ATRIB, k) }
      aviso = lambda do |txt|
        UI.beep
        Sketchup.status_text = txt
        nil
      end
      return aviso.call("Testeira de ilha nao tem janela.") if a.call("so_testeira")
      return aviso.call("Janela de vidro so em parede TS (essa e #{a.call('fechamento')}).") if a.call("fechamento").to_s != "ts"

      pontos = JSON.parse(a.call("pontos"))
      fechado = a.call("fechado") ? true : false
      compartilhados = a.call("compartilhados") ? JSON.parse(a.call("compartilhados")) : []
      trechos = Layout.trechos(pontos, fechado, compartilhados)
      vao = Layout.vao_janela_no_ponto(trechos, x_cm, y_cm)
      return aviso.call("Esse vao e uma folha especial: nao recebe vidro.") unless vao

      porta = a.call("porta").to_s
      porta_pos = a.call("porta_pos") ? JSON.parse(a.call("porta_pos"), symbolize_names: true) : nil
      return aviso.call("Esse vao tem porta. Mova a porta antes.") if porta != "nenhuma" && porta_pos == vao

      atuais = a.call("janelas") ? JSON.parse(a.call("janelas"), symbolize_names: true) : []
      novas = Layout.alternar_janela(atuais, vao)

      model = Sketchup.active_model
      model.start_operation("STAND1 Octanorm: janela de vidro", true)
      begin
        Geometria.construir(model, pontos: pontos, fechado: fechado, altura: a.call("altura").to_f,
                                   fechamento: :ts, testeira: a.call("testeira") ? true : false,
                                   porta: porta.to_sym, porta_pos: porta_pos, grupo: grupo,
                                   compartilhados: compartilhados, janelas: novas)
        model.commit_operation
        Sketchup.status_text = "Janela de vidro em #{novas.size} modulo#{novas.size == 1 ? '' : 's'}. " \
                               "Clique em outro modulo ou Esc pra sair."
        novas
      rescue => e
        model.abort_operation
        UI.messagebox("Erro na janela de vidro:\n#{e.message}")
        nil
      end
    end
  end
end
