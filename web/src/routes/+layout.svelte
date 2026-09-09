<script>
  import "../app.css";
  import Navbar from "$lib/components/Navbar.svelte";
  import Footer from "$lib/components/Footer.svelte";

  let { children } = $props();
  let scrollY = $state(0);
</script>

<svelte:window bind:scrollY />

<div class="app">
  <Navbar {scrollY} />

  <main>
    {@render children()}
  </main>

  <Footer />
</div>

<style>
  .app {
    overflow-x: hidden;
    position: relative;
    width: 100%;
  }

  main {
    min-height: 80vh;
  }
</style>
