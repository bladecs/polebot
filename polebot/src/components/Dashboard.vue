<script setup lang="ts">
import { ref } from "vue";
const isCollapsed = ref(false);
const toggleSidebar = () => (isCollapsed.value = !isCollapsed.value);
</script>

<template>
  <div class="flex h-screen overflow-hidden">
    <!-- Sidebar -->
    <aside
      :class="['sidebar flex flex-col shadow-xl transition-all duration-300', { activate: isCollapsed }]"
    >
      <div class="flex items-center justify-between mb-6 p-3">
        <img v-if="!isCollapsed" src="" alt="Logo" class="w-24" />
        <button @click="toggleSidebar" class="text-white">
          <span class="material-symbols-outlined">
            {{ isCollapsed ? "chevron_right" : "chevron_left" }}
          </span>
        </button>
      </div>

      <!-- Navigation -->
      <nav class="flex flex-col gap-4 p-3 text-white flex-1 overflow-y-auto">
        <a
          href="#"
          class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full"
        >
          <span class="material-symbols-outlined">dashboard</span>
          <span v-if="!isCollapsed">Dashboard</span>
        </a>

        <a
          href="#"
          class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full"
        >
          <span class="material-symbols-outlined">bigtop_updates</span>
          <span v-if="!isCollapsed">Connection</span>
        </a>

        <a
          href="#"
          class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full"
        >
          <span class="material-symbols-outlined">history</span>
          <span v-if="!isCollapsed">History</span>
        </a>

        <a
          href="#"
          class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full"
        >
          <span class="material-symbols-outlined">computer</span>
          <span v-if="!isCollapsed">Monitoring</span>
        </a>
      </nav>

      <div class="mt-auto text-white text-sm" v-if="!isCollapsed">
        Sidebar footer
      </div>
    </aside>

    <!-- Main Content -->
    <main class="flex-1 flex flex-col">
      <!-- Navbar -->
      <header class="h-16 shadow-xl flex items-center justify-between px-6 sticky top-0 z-10 text-white">
        <a href="" class="flex justify-center items-center p-2 rounded-full sidebtn shadow-2xl"><span class="material-symbols-outlined">dehaze</span></a>
        <div class="flex items-center gap-4">
          <span class="material-symbols-outlined cursor-pointer">notifications</span>
          <span class="material-symbols-outlined cursor-pointer">account_circle</span>
        </div>
      </header>

      <!-- Content -->
      <section class="flex-1 overflow-y-auto p-6">
        <h2 class="text-xl font-semibold mb-4">Dashboard Content</h2>
      </section>
    </main>
  </div>
</template>

<style scoped>
/* sidebar lebar normal / collapsed */
.sidebar {
  background: #2a2a2a;
  width: 16rem; /* 256px */
  box-sizing: border-box;
}
.sidebar.activate {
  width: 5rem; /* 80px */
}
/* styling navigasi */
.navigation {
  transition: background 0.2s;
}
.navigation:hover,
.navigation.active {
  background: #878787;
}
header{
    background: #383838;
}
.sidebtn{
    background: #403C3C;
}
</style>
