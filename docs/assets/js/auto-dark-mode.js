// Auto Dark Mode
(function() {
  // Set theme immediately to prevent flash
  const theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  document.documentElement.setAttribute('data-color-scheme', theme);
})();

// Handle theme changes after page load
document.addEventListener('DOMContentLoaded', function() {
  const darkMode = window.matchMedia('(prefers-color-scheme: dark)');

  function applyTheme(e) {
    const theme = e.matches ? 'dark' : 'light';

    // Set both the attribute and jtd theme
    document.documentElement.setAttribute('data-color-scheme', theme);
    if (typeof jtd !== 'undefined' && jtd.setTheme) {
      jtd.setTheme(theme);
    }

    // Update logo on index page
    const indexLogo = document.querySelector('.logo-container img[alt="RubyLLM"]');
    if (indexLogo) {
      indexLogo.src = theme === 'dark' ? '/assets/images/logotype_dark.svg' : '/assets/images/logotype.svg';
    }
  }

  applyTheme(darkMode);
  darkMode.addEventListener('change', applyTheme);
});