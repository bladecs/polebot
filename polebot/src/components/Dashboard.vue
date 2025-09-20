<script setup lang="ts">
import { ref, onMounted } from 'vue'
const isCollapsed = ref(false);
const toggleSidebar = () => (isCollapsed.value = !isCollapsed.value);
import * as ROSLIB from "roslib";

const message = ref("Waiting...")

onMounted(() => {
    const ros = new ROSLIB.Ros({
        url: "ws://localhost:9090"
    })

    const chatter = new ROSLIB.Topic({
        ros: ros,
        name: "/distance_cm",
        messageType: "std_msgs/Int32"
    })

    interface StringMsg {
        data: string
    }

    chatter.subscribe((msgData) => {
        const msg = msgData as StringMsg;
        message.value = msg.data;
        console.log(msg.data);
    })

})
</script>

<template>
    <div class="flex h-screen overflow-hidden">
        <!-- Sidebar -->
        <aside :class="['sidebar flex flex-col shadow-xl transition-all duration-300', { activate: isCollapsed }]">
            <div class="flex items-center justify-center mt-4 mb-6 p-3">
                <img src="../assets/img/logo-polman.png" alt="Logo" class="w-20" />
            </div>

            <hr class="border-white mx-1" />

            <!-- Navigation -->
            <nav class="flex flex-col gap-4 p-3 text-white flex-1 overflow-y-auto">
                <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
                    <span class="material-symbols-outlined">dashboard</span>
                    <span v-if="!isCollapsed">Dashboard</span>
                </a>

                <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
                    <span class="material-symbols-outlined">bigtop_updates</span>
                    <span v-if="!isCollapsed">Connection</span>
                </a>

                <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
                    <span class="material-symbols-outlined">history</span>
                    <span v-if="!isCollapsed">History</span>
                </a>

                <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
                    <span class="material-symbols-outlined">computer</span>
                    <span v-if="!isCollapsed">Monitoring</span>
                </a>
            </nav>

            <hr class="border-white mx-1" />

            <div class="py-3 px-3 text-white text-sm">
                <a href="#" class="navigation flex items-center gap-3 py-3 px-4 rounded-lg w-full">
                    <span class="material-symbols-outlined">account_circle</span>
                    <span v-if="!isCollapsed">Profile</span>
                </a>
            </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 flex flex-col">
            <!-- Navbar -->
            <header class="h-16 shadow-xl flex items-center justify-between px-6 sticky top-0 z-10 text-white">
                <button @click="toggleSidebar"
                    class="cursor-pointer flex justify-center items-center p-2 rounded-full sidebtn shadow-2xl">
                    <span class="material-symbols-outlined">
                        dehaze
                    </span>
                </button>
                <div class="flex items-center gap-4">
                    <p class="font-bold">POLITEKNIK MANUFAKTUR BANDUNG</p>
                    <img src="../assets/img/logo-polman.png" alt="" class="w-8" />
                </div>
            </header>

            <!-- Content -->
            <section class="flex-1 overflow-y-auto p-6">
                <div class="flex-1 h-full flex flex-row gap-4">
                    <div class="content-indicator flex flex-row items-center rounded-2xl w-1/3 h-30">
                        <div class="trape flex justify-center items-center text-white pe-5 rounded-2xl">
                            <span class="material-symbols-outlined" style="font-size: 2.5rem;">computer</span>
                        </div>
                        <p class="w-2/3 text-white ">01</p>
                    </div>
                    <div class="content-indicator flex flex-row items-center rounded-2xl w-1/3 h-30">
                        <div class="trape flex justify-center items-center text-white pe-5 rounded-2xl">
                            <span class="material-symbols-outlined" style="font-size: 2.5rem;">construction</span>
                        </div>
                        <p class="w-2/3 text-white ">01</p>
                    </div>
                    <div class="content-indicator flex flex-row items-center rounded-2xl w-1/3 h-30">
                        <div class="trape flex justify-center items-center text-white pe-5 rounded-2xl">
                            <span class="material-symbols-outlined" style="font-size: 2.5rem;">battery_android_bolt</span>
                        </div>
                        <p class="w-2/3 text-white ">01</p>
                    </div>
                </div>
            </section>
        </main>
    </div>
</template>

<style scoped>
/* sidebar lebar normal / collapsed */
.sidebar {
    background: #2a2a2a;
    width: 16rem;
    /* 256px */
    box-sizing: border-box;
}

.sidebar.activate {
    width: 5rem;
    /* 80px */
}

/* styling navigasi */
.navigation {
    transition: background 0.2s;
}

.navigation:hover,
.navigation.active {
    background: #878787;
}

header {
    background: #383838;
}

.sidebtn {
    background: #403C3C;
}

.content-indicator {
    background: linear-gradient(to top right, #9E9E9E, #383838);
}

.trape {
    width: 50%;
    height: 100%;
    background: #878787;
    clip-path: polygon(0 0, 70% 0, 100% 100%, 0% 100%);
}
</style>
