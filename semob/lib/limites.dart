// Limites usados nos alertas e nos gráficos.
// São valores de EXEMPLO: quem define os limites de verdade é a SEMOB.
const double limiteFcv = 99.5; // FCV mínimo aceitável, em %
const double limiteKmImprodutivo = 6.0; // % máximo de km improdutivo no dia
// Quanto o total de passageiros do dia pode fugir da média do mesmo tipo
// de dia (útil, sábado ou domingo) antes de ser marcado como atípico, em %
const double limiteDesvioPassageiros = 10.0;

// O número do motorista é dado pessoal (LGPD). Deixe desligado até a SEMOB
// confirmar quem pode ver essa informação. Quando houver login por perfil,
// o ideal é mostrar só para quem tem permissão.
const bool exibirMotorista = false;
