import { browser } from '$app/environment';

class ThemeState {
  current = $state('light');

  constructor() {
    if (browser) {
      const savedTheme = localStorage.getItem('theme');
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      this.current = savedTheme || (prefersDark ? 'dark' : 'light');
      this.applyTheme();
    }
  }

  toggle() {
    this.current = this.current === 'dark' ? 'light' : 'dark';
    if (browser) {
      localStorage.setItem('theme', this.current);
      this.applyTheme();
    }
  }

  applyTheme() {
    if (browser) {
      document.documentElement.setAttribute('data-theme', this.current);
    }
  }
}

export const theme = new ThemeState();
