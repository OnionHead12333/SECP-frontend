<template>
  <div class="app">
    <header class="header">
      <h1>智慧养老平台</h1>
      <nav>
        <RouterLink to="/">首页</RouterLink>
      </nav>
    </header>
    <main class="main">
      <RouterView />
    </main>
  </div>
</template>

<script setup>
</script>

<style>
* {
  box-sizing: border-box;
}
body {
  margin: 0;
  font-family: system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  color: #1a1a1a;
  background: #f5f6f8;
}
.app {
  min-height: 100vh;
}
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  background: #fff;
  border-bottom: 1px solid #e8e8e8;
}
.header h1 {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}
.header nav a {
  color: #2563eb;
  text-decoration: none;
}
.header nav a.router-link-active {
  font-weight: 600;
}
.main {
  padding: 1.5rem;
  max-width: 960px;
  margin: 0 auto;
}
</style>
