// Mantém a dependência do navegador fora das compilações nativas.
window.semobSuportaTelaCheia = () => !!document.fullscreenEnabled;
window.semobEmTelaCheia = () => !!document.fullscreenElement;
window.semobTelaCheia = async (ativar) => {
  if (ativar && !document.fullscreenElement) {
    await document.documentElement.requestFullscreen();
  } else if (!ativar && document.fullscreenElement) {
    await document.exitFullscreen();
  }
  return !!document.fullscreenElement;
};
