# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module STAND1
  module Octanorm
    VERSAO = '1.5.0'.freeze
  end
end

octanorm_ext = SketchupExtension.new('STAND1 Octanorm', 'STAND1_Octanorm/core')
octanorm_ext.description = 'Desenha paredes, salas, testeiras de ilha (TS, vidro com spider ou MDF), teto grid Z500 e lista de pecas ' \
                           'clicando no piso, com edicao depois de pronto, ja na tag ESTRUTURAS para o STAND1_Memorial contar o m2.'
octanorm_ext.version     = '1.5.0'
octanorm_ext.creator     = 'Stand1 Producoes'
octanorm_ext.copyright   = '2026 Stand1 Producoes'

Sketchup.register_extension(octanorm_ext, true)
