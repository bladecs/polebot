<template>
    <div class="goal-planning">
        <!-- Header Section -->
        <div class="header-section">
            <div class="header-content">
                <div class="header-icon">
                    <i class="fas fa-crosshairs"></i>
                </div>
                <div class="header-text">
                    <h1>Goal Planning</h1>
                    <p class="subtitle">Click on the map to place navigation goals. Set waypoints for your robot's
                        mission.</p>
                </div>
            </div>
            <div class="header-actions">
                <button class="header-btn" @click="exportGoals" :disabled="goals.length === 0">
                    <i class="fas fa-file-export"></i>
                    <span>Export Goals</span>
                </button>
                <button class="header-btn primary" @click="importGoals">
                    <i class="fas fa-file-import"></i>
                    <span>Import Goals</span>
                </button>
            </div>
        </div>

        <div class="main-layout">
            <!-- Left Panel - Map -->
            <div class="map-section">
                <div class="section-header">
                    <div class="section-title">
                        <div class="title-icon">
                            <i class="fas fa-map"></i>
                        </div>
                        <div class="title-text">
                            <h3>Navigation Map</h3>
                            <p class="section-subtitle">Interactive map for goal placement</p>
                        </div>
                    </div>
                    <div class="section-controls">
                        <div class="control-group">
                            <div class="control-label">Interaction Mode:</div>
                            <div class="mode-buttons">
                                <button @click="setAddGoalMode"
                                    :class="['mode-btn', { active: interactionMode === 'addGoal' }]">
                                    <i
                                        :class="interactionMode === 'addGoal' ? 'fas fa-check-circle' : 'fas fa-plus-circle'"></i>
                                    <span>Add Goal</span>
                                </button>
                                <button @click="setViewMode"
                                    :class="['mode-btn', { active: interactionMode === 'view' }]">
                                    <i class="fas fa-eye"></i>
                                    <span>View Only</span>
                                </button>
                                <button @click="clearAllGoals" class="mode-btn danger">
                                    <i class="fas fa-trash-alt"></i>
                                    <span>Clear All</span>
                                </button>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="map-container">
                    <div class="map-wrapper">
                        <canvas ref="mapCanvas" :width="canvasSize.width" :height="canvasSize.height"
                            :style="canvasStyle" @click="handleMapClick" @mousemove="handleMouseMove"
                            class="map-canvas"></canvas>

                        <!-- Goal indicators -->
                        <div v-for="(goal, index) in goals" :key="index" class="goal-indicator"
                            :style="getGoalIndicatorStyle(goal)" @click="removeGoal(index)"
                            :title="getGoalTooltip(goal)">
                            <div class="goal-marker">
                                <span class="goal-number">{{ index + 1 }}</span>
                                <div class="goal-pulse"></div>
                            </div>
                        </div>

                        <!-- Map Controls Overlay -->
                        <div class="map-controls-overlay">
                            <button class="map-control-btn" @click="zoomIn" title="Zoom In">
                                <i class="fas fa-search-plus"></i>
                            </button>
                            <button class="map-control-btn" @click="zoomOut" title="Zoom Out">
                                <i class="fas fa-search-minus"></i>
                            </button>
                            <button class="map-control-btn" @click="resetView" title="Reset View">
                                <i class="fas fa-expand-arrows-alt"></i>
                            </button>
                        </div>

                        <!-- Map Legend -->
                        <div class="map-legend">
                            <div class="legend-item">
                                <div class="legend-color free"></div>
                                <span>Free Space</span>
                            </div>
                            <div class="legend-item">
                                <div class="legend-color occupied"></div>
                                <span>Obstacle</span>
                            </div>
                            <div class="legend-item">
                                <div class="legend-color unknown"></div>
                                <span>Unknown</span>
                            </div>
                            <div class="legend-item">
                                <div class="legend-color goal"></div>
                                <span>Goal Point</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Map Information Panel -->
                <div class="info-panel">
                    <div class="info-grid">
                        <div class="info-card">
                            <div class="info-icon">
                                <i class="fas fa-ruler-combined"></i>
                            </div>
                            <div class="info-content">
                                <div class="info-label">Map Dimensions</div>
                                <div class="info-value">{{ mapInfo?.width || 0 }} × {{ mapInfo?.height || 0 }} px</div>
                            </div>
                        </div>
                        <div class="info-card">
                            <div class="info-icon">
                                <i class="fas fa-expand-alt"></i>
                            </div>
                            <div class="info-content">
                                <div class="info-label">Resolution</div>
                                <div class="info-value">{{ (mapInfo?.resolution || 0).toFixed(3) }} m/px</div>
                            </div>
                        </div>
                        <div class="info-card">
                            <div class="info-icon">
                                <i class="fas fa-dot-circle"></i>
                            </div>
                            <div class="info-content">
                                <div class="info-label">Origin</div>
                                <div class="info-value">({{ mapInfo?.origin?.x || 0 }}, {{ mapInfo?.origin?.y || 0 }})
                                </div>
                            </div>
                        </div>
                        <div class="info-card">
                            <div class="info-icon">
                                <i class="fas fa-mouse-pointer"></i>
                            </div>
                            <div class="info-content">
                                <div class="info-label">Cursor Position</div>
                                <div class="info-value" v-if="cursorPosition">
                                    X: {{ cursorPosition.x.toFixed(2) }}, Y: {{ cursorPosition.y.toFixed(2) }}
                                </div>
                                <div class="info-value" v-else>Hover over map</div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Right Panel - Goals Management -->
            <div class="goals-section">
                <!-- Goals List Panel -->
                <div class="goals-panel">
                    <div class="section-header">
                        <div class="section-title">
                            <div class="title-icon">
                                <i class="fas fa-bullseye"></i>
                            </div>
                            <div class="title-text">
                                <h3>Planned Goals</h3>
                                <p class="section-subtitle">{{ goals.length }} waypoints configured</p>
                            </div>
                        </div>
                        <div class="goals-count">
                            <span class="count-number">{{ goals.length }}</span>
                            <span class="count-label">GOALS</span>
                        </div>
                    </div>

                    <div v-if="goals.length === 0" class="empty-state">
                        <div class="empty-icon">
                            <i class="fas fa-crosshairs"></i>
                        </div>
                        <h4>No Goals Set</h4>
                        <p>Click on the map in "Add Goal" mode to place your first waypoint.</p>
                        <div class="empty-actions">
                            <button class="action-btn" @click="addSampleGoals">
                                <i class="fas fa-magic"></i>
                                Add Sample Goals
                            </button>
                        </div>
                    </div>

                    <div v-else class="goals-list">
                        <div class="goals-list-header">
                            <div class="header-item">#</div>
                            <div class="header-item">Coordinates</div>
                            <div class="header-item">Time</div>
                            <div class="header-item">Actions</div>
                        </div>
                        <div class="goals-list-content">
                            <div v-for="(goal, index) in goals" :key="index" class="goal-list-item"
                                :class="{ active: selectedGoal === index }" @click="selectGoal(index)">
                                <div class="list-item-number">
                                    <span class="goal-badge">{{ index + 1 }}</span>
                                </div>
                                <div class="list-item-coords">
                                    <div class="coord-display">
                                        <div class="coord-x">
                                            <i class="fas fa-long-arrow-alt-right"></i>
                                            {{ goal.x.toFixed(2) }}
                                        </div>
                                        <div class="coord-y">
                                            <i class="fas fa-long-arrow-alt-up"></i>
                                            {{ goal.y.toFixed(2) }}
                                        </div>
                                    </div>
                                </div>
                                <div class="list-item-time">
                                    <div class="time-display">
                                        <i class="far fa-clock"></i>
                                        {{ formatTimeAgo(goal.timestamp) }}
                                    </div>
                                </div>
                                <div class="list-item-actions">
                                    <button class="list-action-btn" @click.stop="editGoal(index)" title="Edit Goal">
                                        <i class="fas fa-edit"></i>
                                    </button>
                                    <button class="list-action-btn danger" @click.stop="removeGoal(index)"
                                        title="Remove Goal">
                                        <i class="fas fa-trash"></i>
                                    </button>
                                    <button class="list-action-btn success" @click.stop="sendSingleGoal(goal)"
                                        title="Send to Robot" :disabled="!isConnected">
                                        <i class="fas fa-paper-plane"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Goals Actions -->
                    <div class="goals-actions">
                        <div class="action-group">
                            <button class="action-btn" @click="saveGoalsToDatabase"
                                :disabled="goals.length === 0 || isSavingGoals">
                                <i class="fas" :class="isSavingGoals ? 'fa-spinner fa-spin' : 'fa-database'"></i>
                                <span class="btn-text">{{ isSavingGoals ? 'Saving...' : 'Save to DB' }}</span>
                            </button>
                            <button class="action-btn" @click="showGoalSetSelector" :disabled="isLoadingGoals">
                                <i class="fas" :class="isLoadingGoals ? 'fa-spinner fa-spin' : 'fa-folder-open'"></i>
                                <span class="btn-text">{{ isLoadingGoals ? 'Loading...' : 'Load from DB' }}</span>
                            </button>
                            <button class="action-btn" @click="saveGoals" :disabled="goals.length === 0">
                                <i class="fas fa-download"></i>
                                <span class="btn-text">Export JSON</span>
                            </button>
                        </div>

                        <!-- Current Goal Set Info -->
                        <div v-if="currentGoalSet" class="current-goal-set">
                            <div class="goal-set-info">
                                <span class="set-name">
                                    <i class="fas fa-folder"></i>
                                    {{ currentGoalSet.name }}
                                </span>
                                <span class="map-name">
                                    <i class="fas fa-map"></i>
                                    {{ currentGoalSet.mapName }}
                                </span>
                                <div class="set-actions">
                                    <button class="action-btn small" @click="updateCurrentGoalSet"
                                        :disabled="isSavingGoals">
                                        <i class="fas fa-sync-alt"></i>
                                        Update
                                    </button>
                                    <button class="action-btn small danger" @click="deleteGoalSet(currentGoalSet.name)">
                                        <i class="fas fa-trash"></i>
                                        Delete
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Quick Actions Panel -->
                <div class="quick-actions-panel">
                    <div class="section-header">
                        <div class="section-title">
                            <div class="title-icon">
                                <i class="fas fa-bolt"></i>
                            </div>
                            <h3>Quick Actions</h3>
                        </div>
                        <!-- Toggle button untuk mobile -->
                        <button class="mobile-toggle" @click="toggleQuickActions" v-if="isMobile">
                            <i class="fas" :class="showQuickActions ? 'fa-chevron-up' : 'fa-chevron-down'"></i>
                        </button>
                    </div>
                    
                    <!-- Wrap content untuk bisa di-toggle -->
                    <div class="quick-actions-content" :class="{ 'collapsed': !showQuickActions && isMobile }">
                        <div class="quick-action-input">
                            <label class="input-label">
                                <span class="label-text">Map Name:</span>
                                <input v-model="mapSaveName" type="text" placeholder="polebot_map" class="input-field"
                                    :disabled="!isConnected || isSavingMap">
                                <div class="input-hint">File extensions (.yaml, .pgm) will be added automatically</div>
                            </label>
                        </div>
                        <div class="quick-actions-grid">
                            <button class="quick-action-btn" @click="centerMap" :disabled="!mapInfo">
                                <div class="action-icon">
                                    <i class="fas fa-crosshairs"></i>
                                </div>
                                <div class="action-text">
                                    <div class="action-title">Center Map</div>
                                    <div class="action-desc">Reset map view</div>
                                </div>
                            </button>
                            <button class="quick-action-btn" @click="testConnection" :disabled="!isConnected">
                                <div class="action-icon">
                                    <i class="fas fa-wifi"></i>
                                </div>
                                <div class="action-text">
                                    <div class="action-title">Test Connection</div>
                                    <div class="action-desc">Verify ROS bridge</div>
                                </div>
                            </button>
                            <button class="quick-action-btn" @click="saveMapWithCorrectFormat" :disabled="!mapData">
                                <div class="action-icon">
                                    <i class="fas fa-save"></i>
                                </div>
                                <div class="action-text">
                                    <div class="action-title">Save Map</div>
                                    <div class="action-desc">Save as PGM/YAML</div>
                                </div>
                            </button>
                            <button class="quick-action-btn" @click="showHelp">
                                <div class="action-icon">
                                    <i class="fas fa-question-circle"></i>
                                </div>
                                <div class="action-text">
                                    <div class="action-title">Help</div>
                                    <div class="action-desc">View documentation</div>
                                </div>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
export default {
    name: 'GoalPlanning',
    props: {
        isConnected: Boolean,
        ros: Object,
        goals: Array,
        mapData: Object,
        mapInfo: Object,
        connectionStatus: {
            type: Object,
            required: true,
            default: () => ({
                message: 'Disconnected',
                class: 'disconnected',
                icon: 'fas fa-plug'
            })
        }
    },
    data() {
        return {
            canvasSize: { width: 100, height: 100 },
            interactionMode: 'addGoal',
            cursorPosition: null,
            selectedGoal: null,
            offset: { x: 0, y: 0, scale: 1.0 },
            mouseX: 0,
            mouseY: 0,
            mapSaveName: '',
            mapSaveDirectory: '~/polman-mbd-ros2-polebot-amr/src/polebot_amr_navigation/maps',
            isSavingMap: false,
            lastSaveStatus: null,
            serviceInfo: null,
            currentGoalSet: null,
            goalSets: [],
            isSavingGoals: false,
            isLoadingGoals: false,
            showQuickActions: true,
            isMobile: false
        }
    },
    computed: {
        statusIcon() {
            return this.connectionStatus?.icon || 'fas fa-circle'
        },

        canvasStyle() {
            return {
                width: (this.canvasSize.width * 2 * this.offset.scale) + 'px',
                height: (this.canvasSize.height * 2 * this.offset.scale) + 'px',
                cursor: this.interactionMode === 'addGoal' ? 'crosshair' : 'default'
            }
        }
    },
    mounted() {
        this.renderMap()
        this.checkMobile();
        window.addEventListener('resize', this.checkMobile);
    },
    beforeUnmount() {
        const canvas = this.$refs.mapCanvas
        if (canvas) {
            canvas.removeEventListener('mousemove', this.handleMouseMove)
        }
        window.removeEventListener('resize', this.checkMobile);
    },
    watch: {
        mapData() {
            this.renderMap()
        }
    },
    methods: {
        checkMobile() {
            this.isMobile = window.innerWidth <= 768;
            if (!this.isMobile) {
                this.showQuickActions = true;
            }
        },

        toggleQuickActions() {
            this.showQuickActions = !this.showQuickActions;
        },

        handleMouseMove(event) {
            if (!this.mapData || !this.mapInfo) return

            const canvas = this.$refs.mapCanvas
            const rect = canvas.getBoundingClientRect()
            const scale = 2 * this.offset.scale

            const mouseX = event.clientX - rect.left
            const mouseY = event.clientY - rect.top

            const pixelX = Math.floor(mouseX / scale)
            const pixelY = Math.floor(mouseY / scale)

            const mapCoords = this.pixelToMapCoordinates(pixelX, pixelY)
            if (mapCoords) {
                this.cursorPosition = {
                    x: mapCoords.mapX,
                    y: mapCoords.mapY
                }
            }
        },

        renderMap() {
            if (!this.mapData || !this.$refs.mapCanvas) return

            const canvas = this.$refs.mapCanvas
            const ctx = canvas.getContext('2d')
            const width = this.mapData.info.width
            const height = this.mapData.info.height
            const data = this.mapData.data

            this.canvasSize = { width, height }

            ctx.clearRect(0, 0, width, height)
            const imageData = ctx.createImageData(width, height)

            for (let y = 0; y < height; y++) {
                for (let x = 0; x < width; x++) {
                    const index = y * width + x
                    const pixelIndex = (y * width + x) * 4
                    const cellValue = data[index]

                    let r, g, b
                    if (cellValue === -1) {
                        r = g = b = 128 // Unknown - gray
                    } else if (cellValue === 0) {
                        r = g = b = 255 // Free - white
                    } else if (cellValue === 100) {
                        r = g = b = 0   // Occupied - black
                    } else {
                        r = 255; g = 200; b = 0 // Unknown - yellow
                    }

                    imageData.data[pixelIndex] = r
                    imageData.data[pixelIndex + 1] = g
                    imageData.data[pixelIndex + 2] = b
                    imageData.data[pixelIndex + 3] = 255
                }
            }

            ctx.putImageData(imageData, 0, 0)
        },

        handleMapClick(event) {
            if (this.interactionMode !== 'addGoal' || !this.mapData || !this.mapInfo) return

            const canvas = this.$refs.mapCanvas
            const rect = canvas.getBoundingClientRect()
            const scale = 2 * this.offset.scale

            const clickX = event.clientX - rect.left
            const clickY = event.clientY - rect.top

            const pixelX = Math.floor(clickX / scale)
            const pixelY = Math.floor(clickY / scale)

            const mapCoords = this.pixelToMapCoordinates(pixelX, pixelY)
            if (!mapCoords) return

            const newGoal = {
                x: mapCoords.mapX,
                y: mapCoords.mapY,
                timestamp: Date.now(),
                id: Date.now() + Math.random()
            }

            this.$emit('update-goals', [...this.goals, newGoal])
            console.log(`🎯 Added goal: X:${mapCoords.mapX.toFixed(2)}, Y:${mapCoords.mapY.toFixed(2)}`)

            this.renderMap()
        },

        pixelToMapCoordinates(px, py) {
            if (!this.mapData || !this.mapInfo) return null

            const origin = this.mapData.info.origin.position
            const resolution = this.mapData.info.resolution

            const adjustedPx = (px - this.offset.x) / this.offset.scale
            const adjustedPy = (py - this.offset.y) / this.offset.scale

            const mapX = origin.x + (adjustedPx * resolution)
            const mapY = origin.y + (adjustedPy * resolution)

            return { mapX, mapY }
        },

        calculatePixelCoordinates(mapX, mapY) {
            if (!this.mapData || !this.mapInfo) return { px: 0, py: 0 }

            const origin = this.mapData.info.origin.position
            const resolution = this.mapData.info.resolution
            const width = this.mapInfo.width
            const height = this.mapInfo.height

            const continuousX = (mapX - origin.x) / resolution
            const continuousY = (mapY - origin.y) / resolution

            const pixelX = Math.round(continuousX * this.offset.scale + this.offset.x)
            const pixelY = Math.round(continuousY * this.offset.scale + this.offset.y)

            return {
                px: Math.max(0, Math.min(pixelX, width - 1)),
                py: Math.max(0, Math.min(pixelY, height - 1))
            }
        },

        getGoalIndicatorStyle(goal) {
            if (!goal) return { left: '0px', top: '0px' }

            const pixelCoords = this.calculatePixelCoordinates(goal.x, goal.y)
            const scale = 2 * this.offset.scale

            return {
                left: (pixelCoords.px * scale - 20) + 'px',
                top: (pixelCoords.py * scale - 20) + 'px'
            }
        },

        getGoalTooltip(goal) {
            if (!goal) return 'Goal: No data'
            return `Goal: X:${goal.x.toFixed(2)}, Y:${goal.y.toFixed(2)}`
        },

        formatTimeAgo(timestamp) {
            if (!timestamp) return ''
            const now = Date.now()
            const diff = now - timestamp

            const minutes = Math.floor(diff / 60000)
            if (minutes < 1) return 'Just now'
            if (minutes < 60) return `${minutes}m ago`

            const hours = Math.floor(minutes / 60)
            if (hours < 24) return `${hours}h ago`

            const days = Math.floor(hours / 24)
            return `${days}d ago`
        },

        setAddGoalMode() {
            this.interactionMode = 'addGoal'
        },

        setViewMode() {
            this.interactionMode = 'view'
        },

        selectGoal(index) {
            this.selectedGoal = this.selectedGoal === index ? null : index
        },

        // Method untuk save ke database
        async saveGoalsToDatabase() {
            if (this.goals.length === 0) {
                this.showNotification('warning', 'No goals to save');
                return;
            }

            try {
                // Prompt untuk nama goal set
                const defaultName = `goals_${new Date().toISOString().slice(0, 10)}`;
                const setName = prompt('Enter goal set name:', defaultName);

                if (!setName) return;

                const description = prompt('Description (optional):', '') || '';

                // Tampilkan loading
                this.isSavingGoals = true;
                this.showNotification('info', 'Saving goals to database...');

                const goalData = {
                    mapName: this.mapSaveName || 'default_map',
                    setName: setName,
                    goals: this.goals.map((goal, index) => ({
                        x: goal.x,
                        y: goal.y,
                        sequence_number: index + 1,
                        orientation_z: goal.orientation_z || 0.0,
                        orientation_w: goal.orientation_w || 1.0,
                        tolerance_xy: 0.3,
                        tolerance_yaw: 0.5
                    })),
                    mapInfo: {
                        resolution: this.mapInfo?.resolution || 0.05,
                        origin: this.mapInfo?.origin || { x: 0, y: 0 },
                        width: this.mapInfo?.width || 0,
                        height: this.mapInfo?.height || 0
                    },
                    description: description
                };

                // Kirim ke API
                const response = await fetch('http://localhost:3000/api/goals/save', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(goalData)
                });

                const result = await response.json();

                if (response.ok) {
                    this.showNotification('success',
                        `Goal set "${setName}" saved successfully with ${this.goals.length} goals`);

                    // Simpan goal set info
                    this.currentGoalSet = {
                        id: result.data.goalSetId,
                        name: setName,
                        mapName: result.data.mapName
                    };

                    // Refresh list goal sets
                    await this.loadGoalSets();

                } else {
                    throw new Error(result.error || 'Failed to save goal set');
                }

            } catch (error) {
                console.error('Error saving goal set:', error);
                this.showNotification('error', `Failed to save goals: ${error.message}`);
            } finally {
                this.isSavingGoals = false;
            }
        },

        async loadGoalSets() {
            try {
                this.isLoadingGoals = true;

                const response = await fetch('http://localhost:3000/api/goals/sets');
                const result = await response.json();

                if (!response.ok) {
                    throw new Error(result.error || 'Failed to load goal sets');
                }

                this.goalSets = result.goalSets;

                return result.goalSets;

            } catch (error) {
                console.error('Error loading goal sets:', error);
                this.showNotification('error', `Failed to load goal sets: ${error.message}`);
                return [];
            } finally {
                this.isLoadingGoals = false;
            }
        },

        async loadGoalSet(setName) {
            try {
                this.isLoadingGoals = true;
                this.showNotification('info', `Loading goal set "${setName}"...`);

                const response = await fetch(`http://localhost:3000/api/goals/set/${setName}`);
                const result = await response.json();

                if (!response.ok) {
                    throw new Error(result.error || 'Failed to load goal set');
                }

                // Convert database goals ke format Vue
                const vueGoals = result.goals.map(goal => ({
                    x: parseFloat(goal.x),
                    y: parseFloat(goal.y),
                    orientation_z: parseFloat(goal.orientation_z) || 0.0,
                    orientation_w: parseFloat(goal.orientation_w) || 1.0,
                    timestamp: new Date(goal.created_at).getTime(),
                    id: `${result.goalSet.id}_${goal.sequence_number}`
                }));

                // Update goals di Vue
                this.$emit('update-goals', vueGoals);

                // Update current goal set
                this.currentGoalSet = {
                    id: result.goalSet.id,
                    name: setName,
                    mapName: result.goalSet.map_name
                };

                // Update map info jika tersedia
                if (result.goalSet.map_name) {
                    this.mapSaveName = result.goalSet.map_name;
                }

                this.showNotification('success',
                    `Loaded "${setName}" with ${vueGoals.length} goals`);

                this.renderMap();

                return result;

            } catch (error) {
                console.error('Error loading goal set:', error);
                this.showNotification('error', `Failed to load goal set: ${error.message}`);
                throw error;
            } finally {
                this.isLoadingGoals = false;
            }
        },

        async loadGoalSetById(id) {
            try {
                this.isLoadingGoals = true;

                const response = await fetch(`http://localhost:3000/api/goals/set/id/${id}`);
                const result = await response.json();

                if (!response.ok) {
                    throw new Error(result.error || 'Failed to load goal set');
                }

                // Convert database goals ke format Vue
                const vueGoals = result.goals.map(goal => ({
                    x: parseFloat(goal.x),
                    y: parseFloat(goal.y),
                    orientation_z: parseFloat(goal.orientation_z) || 0.0,
                    orientation_w: parseFloat(goal.orientation_w) || 1.0,
                    timestamp: new Date(goal.created_at).getTime(),
                    id: `${result.goalSet.id}_${goal.sequence_number}`
                }));

                // Update goals di Vue
                this.$emit('update-goals', vueGoals);

                // Update current goal set
                this.currentGoalSet = {
                    id: result.goalSet.id,
                    name: result.goalSet.name,
                    mapName: result.goalSet.map_name
                };

                // Update map info jika tersedia
                if (result.goalSet.map_name) {
                    this.mapSaveName = result.goalSet.map_name;
                }

                this.showNotification('success',
                    `Loaded "${result.goalSet.name}" with ${vueGoals.length} goals`);

                this.renderMap();

                return result;

            } catch (error) {
                console.error('Error loading goal set:', error);
                this.showNotification('error', `Failed to load goal set: ${error.message}`);
                throw error;
            } finally {
                this.isLoadingGoals = false;
            }
        },

        async updateCurrentGoalSet() {
            if (!this.currentGoalSet || !this.currentGoalSet.name) {
                this.showNotification('warning', 'No goal set selected');
                return;
            }

            if (this.goals.length === 0) {
                if (!confirm('Goal set will be empty. Continue?')) return;
            }

            try {
                this.isSavingGoals = true;
                this.showNotification('info', `Updating "${this.currentGoalSet.name}"...`);

                const response = await fetch(`http://localhost:3000/api/goals/set/${this.currentGoalSet.name}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                        goals: this.goals.map((goal, index) => ({
                            x: goal.x,
                            y: goal.y,
                            orientation_z: goal.orientation_z || 0.0,
                            orientation_w: goal.orientation_w || 1.0
                        }))
                    })
                });

                const result = await response.json();

                if (response.ok) {
                    this.showNotification('success',
                        `Goal set "${this.currentGoalSet.name}" updated with ${this.goals.length} goals`);
                } else {
                    throw new Error(result.error || 'Failed to update goal set');
                }

            } catch (error) {
                console.error('Error updating goal set:', error);
                this.showNotification('error', `Failed to update goal set: ${error.message}`);
            } finally {
                this.isSavingGoals = false;
            }
        },

        async deleteGoalSet(setName) {
            if (!confirm(`Are you sure you want to delete "${setName}"?`)) return;

            try {
                const response = await fetch(`http://localhost:3000/api/goals/set/${setName}`, {
                    method: 'DELETE'
                });

                const result = await response.json();

                if (response.ok) {
                    this.showNotification('success', `Goal set "${setName}" deleted`);

                    // Reset current goal set jika yang dihapus adalah yang sedang aktif
                    if (this.currentGoalSet && this.currentGoalSet.name === setName) {
                        this.currentGoalSet = null;
                        this.$emit('update-goals', []);
                    }

                    // Refresh list
                    await this.loadGoalSets();
                } else {
                    throw new Error(result.error || 'Failed to delete goal set');
                }
            } catch (error) {
                console.error('Error deleting goal set:', error);
                this.showNotification('error', `Failed to delete goal set: ${error.message}`);
            }
        },

        async showGoalSetSelector() {
            try {
                // Load goal sets jika belum diload
                if (this.goalSets.length === 0) {
                    await this.loadGoalSets();
                }

                if (this.goalSets.length === 0) {
                    this.showNotification('info', 'No saved goal sets found');
                    return;
                }

                // Buat dialog sederhana untuk memilih goal set
                let selectorHtml = `
                    <div class="goal-set-selector">
                        <div class="selector-header">
                            <h3>Select Goal Set</h3>
                            <button class="close-modal">&times;</button>
                        </div>
                        <div class="search-box">
                            <input type="text" id="searchInput" placeholder="Search goal sets..." class="search-input">
                            <i class="fas fa-search search-icon"></i>
                        </div>
                        <div class="goal-set-list">
                `;
                
                this.goalSets.forEach((set, index) => {
                    const date = new Date(set.created_at);
                    selectorHtml += `
                        <div class="goal-set-item" data-index="${index}" data-name="${set.set_name}">
                            <div class="item-main">
                                <div class="item-header">
                                    <strong class="set-name">${set.set_name}</strong>
                                    <span class="goal-count">${set.saved_goals} goals</span>
                                </div>
                                <div class="item-details">
                                    <span class="map-name">
                                        <i class="fas fa-map"></i> ${set.map_name}
                                    </span>
                                    <span class="date">
                                        <i class="far fa-calendar"></i> ${date.toLocaleDateString()}
                                    </span>
                                </div>
                                ${set.description ? `<div class="item-description">${set.description}</div>` : ''}
                            </div>
                            <div class="item-actions">
                                <button class="load-btn" data-name="${set.set_name}">Load</button>
                            </div>
                        </div>
                    `;
                });
                
                selectorHtml += `
                        </div>
                        <div class="no-results" style="display: none;">
                            <i class="fas fa-search"></i>
                            <p>No goal sets found</p>
                        </div>
                        <div class="selector-footer">
                            <button id="cancelBtn" class="cancel-btn">Cancel</button>
                        </div>
                    </div>
                `;

                // Buat modal
                const modal = document.createElement('div');
                modal.className = 'goal-set-modal';
                modal.innerHTML = selectorHtml;
                
                // Tambahkan style modal
                this.addModalStyles();
                
                document.body.appendChild(modal);
                document.body.style.overflow = 'hidden'; // Prevent scrolling

                // Event listener untuk search
                const searchInput = modal.querySelector('#searchInput');
                const goalSetItems = modal.querySelectorAll('.goal-set-item');
                const noResults = modal.querySelector('.no-results');

                searchInput.addEventListener('input', (e) => {
                    const searchTerm = e.target.value.toLowerCase();
                    let visibleCount = 0;
                    
                    goalSetItems.forEach(item => {
                        const setName = item.dataset.name.toLowerCase();
                        const mapName = item.querySelector('.map-name').textContent.toLowerCase();
                        const description = item.querySelector('.item-description')?.textContent.toLowerCase() || '';
                        
                        if (setName.includes(searchTerm) || mapName.includes(searchTerm) || description.includes(searchTerm)) {
                            item.style.display = 'flex';
                            visibleCount++;
                        } else {
                            item.style.display = 'none';
                        }
                    });
                    
                    noResults.style.display = visibleCount === 0 ? 'block' : 'none';
                });

                // Event listener untuk load button
                modal.querySelectorAll('.load-btn').forEach(btn => {
                    btn.addEventListener('click', async () => {
                        const setName = btn.dataset.name;
                        document.body.removeChild(modal);
                        document.body.style.overflow = 'auto';
                        await this.loadGoalSet(setName);
                    });
                });

                // Event listener untuk close button
                modal.querySelector('.close-modal').addEventListener('click', () => {
                    document.body.removeChild(modal);
                    document.body.style.overflow = 'auto';
                });

                modal.querySelector('#cancelBtn').addEventListener('click', () => {
                    document.body.removeChild(modal);
                    document.body.style.overflow = 'auto';
                });

                // Close modal ketika klik di luar
                modal.addEventListener('click', (e) => {
                    if (e.target === modal) {
                        document.body.removeChild(modal);
                        document.body.style.overflow = 'auto';
                    }
                });

            } catch (error) {
                console.error('Error showing goal set selector:', error);
                this.showNotification('error', 'Failed to load goal sets');
            }
        },

        addModalStyles() {
            // Hapus style yang sudah ada jika ada
            const existingStyle = document.getElementById('modal-styles');
            if (existingStyle) existingStyle.remove();
            
            // Tambahkan style baru
            const style = document.createElement('style');
            style.id = 'modal-styles';
            style.textContent = `
                .goal-set-modal {
                    position: fixed;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    background: rgba(0, 0, 0, 0.8);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 10000;
                    padding: 20px;
                    backdrop-filter: blur(5px);
                }
                
                .goal-set-selector {
                    background: var(--card-bg, #1e293b);
                    border: 1px solid var(--border-color, #334155);
                    border-radius: 16px;
                    width: 600px;
                    max-width: 95%;
                    max-height: 80vh;
                    display: flex;
                    flex-direction: column;
                    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
                }
                
                .selector-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 20px 24px;
                    border-bottom: 1px solid var(--border-color, #334155);
                }
                
                .selector-header h3 {
                    margin: 0;
                    font-size: 20px;
                    color: var(--text-primary, #f1f5f9);
                    font-weight: 600;
                }
                
                .close-modal {
                    background: none;
                    border: none;
                    color: var(--text-muted, #94a3b8);
                    font-size: 24px;
                    cursor: pointer;
                    padding: 0;
                    width: 30px;
                    height: 30px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    border-radius: 6px;
                    transition: all 0.3s ease;
                }
                
                .close-modal:hover {
                    background: rgba(255, 255, 255, 0.1);
                    color: var(--text-primary, #f1f5f9);
                }
                
                .search-box {
                    position: relative;
                    padding: 16px 24px;
                    border-bottom: 1px solid var(--border-color, #334155);
                }
                
                .search-input {
                    width: 100%;
                    padding: 12px 16px 12px 44px;
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid var(--border-color, #334155);
                    border-radius: 10px;
                    color: var(--text-primary, #f1f5f9);
                    font-size: 14px;
                    transition: all 0.3s ease;
                }
                
                .search-input:focus {
                    outline: none;
                    border-color: var(--accent-blue, #3b82f6);
                    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
                }
                
                .search-icon {
                    position: absolute;
                    left: 36px;
                    top: 50%;
                    transform: translateY(-50%);
                    color: var(--text-muted, #94a3b8);
                    font-size: 14px;
                }
                
                .goal-set-list {
                    flex: 1;
                    overflow-y: auto;
                    padding: 16px 24px;
                    display: flex;
                    flex-direction: column;
                    gap: 12px;
                }
                
                .goal-set-item {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 16px;
                    background: rgba(255, 255, 255, 0.03);
                    border: 1px solid var(--border-color, #334155);
                    border-radius: 12px;
                    transition: all 0.3s ease;
                    gap: 16px;
                }
                
                .goal-set-item:hover {
                    background: rgba(255, 255, 255, 0.05);
                    border-color: var(--accent-blue, #3b82f6);
                    transform: translateY(-2px);
                }
                
                .item-main {
                    flex: 1;
                }
                
                .item-header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    margin-bottom: 8px;
                }
                
                .set-name {
                    font-size: 15px;
                    color: var(--text-primary, #f1f5f9);
                    font-weight: 600;
                    margin: 0;
                }
                
                .goal-count {
                    background: var(--accent-blue, #3b82f6);
                    color: white;
                    padding: 4px 8px;
                    border-radius: 20px;
                    font-size: 12px;
                    font-weight: 600;
                }
                
                .item-details {
                    display: flex;
                    gap: 16px;
                    margin-bottom: 8px;
                }
                
                .map-name, .date {
                    display: flex;
                    align-items: center;
                    gap: 6px;
                    font-size: 12px;
                    color: var(--text-muted, #94a3b8);
                }
                
                .item-description {
                    font-size: 13px;
                    color: var(--text-secondary, #cbd5e1);
                    line-height: 1.5;
                    margin-top: 4px;
                    opacity: 0.9;
                }
                
                .item-actions {
                    flex-shrink: 0;
                }
                
                .load-btn {
                    background: var(--accent-blue, #3b82f6);
                    color: white;
                    border: none;
                    padding: 8px 16px;
                    border-radius: 8px;
                    font-size: 13px;
                    font-weight: 600;
                    cursor: pointer;
                    transition: all 0.3s ease;
                    white-space: nowrap;
                }
                
                .load-btn:hover {
                    background: var(--accent-purple, #8b5cf6);
                    transform: translateY(-2px);
                }
                
                .no-results {
                    text-align: center;
                    padding: 40px 20px;
                    color: var(--text-muted, #94a3b8);
                }
                
                .no-results i {
                    font-size: 48px;
                    margin-bottom: 16px;
                    opacity: 0.5;
                }
                
                .no-results p {
                    margin: 0;
                    font-size: 14px;
                }
                
                .selector-footer {
                    padding: 20px 24px;
                    border-top: 1px solid var(--border-color, #334155);
                    display: flex;
                    justify-content: flex-end;
                }
                
                .cancel-btn {
                    background: rgba(255, 255, 255, 0.05);
                    color: var(--text-secondary, #cbd5e1);
                    border: 1px solid var(--border-color, #334155);
                    padding: 10px 20px;
                    border-radius: 8px;
                    font-size: 14px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.3s ease;
                }
                
                .cancel-btn:hover {
                    background: rgba(255, 255, 255, 0.1);
                    color: var(--text-primary, #f1f5f9);
                }
                
                @media (max-width: 768px) {
                    .goal-set-item {
                        flex-direction: column;
                        align-items: stretch;
                        gap: 12px;
                    }
                    
                    .item-header {
                        flex-direction: column;
                        align-items: flex-start;
                        gap: 8px;
                    }
                    
                    .item-details {
                        flex-wrap: wrap;
                        gap: 8px;
                    }
                    
                    .load-btn {
                        width: 100%;
                    }
                }
                
                @media (max-width: 480px) {
                    .goal-set-selector {
                        max-height: 90vh;
                    }
                    
                    .selector-header,
                    .search-box,
                    .goal-set-list,
                    .selector-footer {
                        padding: 16px;
                    }
                    
                    .goal-set-item {
                        padding: 12px;
                    }
                }
            `;
            
            document.head.appendChild(style);
        },

        async searchGoalSets(searchTerm) {
            try {
                const response = await fetch(`http://localhost:3000/api/goals/search?name=${encodeURIComponent(searchTerm)}`);
                const result = await response.json();

                if (response.ok) {
                    return result.goalSets;
                } else {
                    throw new Error(result.error || 'Failed to search goal sets');
                }
            } catch (error) {
                console.error('Error searching goal sets:', error);
                return [];
            }
        },

        showNotification(type, message) {
            // Buat elemen notifikasi
            const notification = document.createElement('div');
            notification.className = `api-notification ${type}`;
            notification.innerHTML = `
                <i class="fas fa-${type === 'success' ? 'check-circle' : 'exclamation-circle'}"></i>
                <span>${message}</span>
                <button class="close-btn">&times;</button>
            `;

            // Style notifikasi
            notification.style.cssText = `
                position: fixed;
                top: 20px;
                right: 20px;
                background: ${type === 'success' ? 'var(--accent-green)' : 'var(--accent-red)'};
                color: white;
                padding: 12px 20px;
                border-radius: 8px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                display: flex;
                align-items: center;
                gap: 10px;
                z-index: 10000;
                animation: slideIn 0.3s ease;
                max-width: 400px;
            `;

            // Animasi
            const style = document.createElement('style');
            style.textContent = `
                @keyframes slideIn {
                    from { transform: translateX(100%); opacity: 0; }
                    to { transform: translateX(0); opacity: 1; }
                }
                .close-btn {
                    background: none;
                    border: none;
                    color: white;
                    font-size: 20px;
                    cursor: pointer;
                    padding: 0;
                    margin-left: 10px;
                }
            `;
            document.head.appendChild(style);

            // Tambahkan event listener untuk close button
            notification.querySelector('.close-btn').onclick = () => {
                notification.remove();
            };

            // Auto remove setelah 5 detik
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.remove();
                }
            }, 5000);

            document.body.appendChild(notification);
        },

        removeGoal(index) {
            const newGoals = [...this.goals]
            newGoals.splice(index, 1)
            this.$emit('update-goals', newGoals)
            if (this.selectedGoal === index) this.selectedGoal = null
            this.renderMap()
        },

        editGoal(index) {
            const goal = this.goals[index]
            const newX = prompt('Enter new X coordinate:', goal.x.toFixed(2))
            const newY = prompt('Enter new Y coordinate:', goal.y.toFixed(2))

            if (newX !== null && newY !== null) {
                const newGoals = [...this.goals]
                newGoals[index] = {
                    ...goal,
                    x: parseFloat(newX),
                    y: parseFloat(newY),
                    timestamp: Date.now()
                }
                this.$emit('update-goals', newGoals)
                this.renderMap()
            }
        },

        clearAllGoals() {
            if (confirm('Are you sure you want to clear all goals?')) {
                this.$emit('update-goals', [])
                this.selectedGoal = null
                this.renderMap()
            }
        },

        sendSingleGoal(goal) {
            if (!this.isConnected || !goal) {
                alert('ROS not connected')
                return
            }

            if (!this.ros) {
                alert('ROS instance not available')
                return
            }

            try {
                const goalTopic = new ROSLIB.Topic({
                    ros: this.ros,
                    name: '/goal_pose',
                    messageType: 'geometry_msgs/msg/PoseStamped'
                })

                const goalMessage = new ROSLIB.Message({
                    header: {
                        stamp: { sec: 0, nanosec: 0 },
                        frame_id: 'map'
                    },
                    pose: {
                        position: {
                            x: goal.x,
                            y: goal.y,
                            z: 0.0
                        },
                        orientation: { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
                    }
                })

                goalTopic.publish(goalMessage)
                alert(`✅ Goal sent to robot: X:${goal.x.toFixed(2)}, Y:${goal.y.toFixed(2)}`)
            } catch (error) {
                alert(`❌ Error sending goal: ${error.message}`)
            }
        },

        saveGoals() {
            const goalsData = JSON.stringify(this.goals, null, 2)
            const blob = new Blob([goalsData], { type: 'application/json' })
            const url = URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            a.download = `nav2_goals_${new Date().toISOString().slice(0, 10)}.json`
            document.body.appendChild(a)
            a.click()
            document.body.removeChild(a)
            URL.revokeObjectURL(url)
        },

        getTimeStamp() {
            const now = new Date();
            return `${now.getHours().toString().padStart(2, '0')}${now.getMinutes().toString().padStart(2, '0')}`;
        },

        /**
         * ✅ CORRECTED - Menggunakan std_msgs/String untuk field name
         */
        async saveMapWithCorrectFormat() {
            if (!this.isConnected || this.isSavingMap) {
                console.warn('Cannot save map: ROS not connected or already saving');
                return;
            }

            this.isSavingMap = true;
            this.lastSaveStatus = {
                type: 'info',
                icon: 'fas fa-info-circle',
                message: 'Saving map with std_msgs/String format...'
            };

            try {
                // Validate inputs
                if (!this.mapSaveName || this.mapSaveName.trim() === '') {
                    throw new Error('Map name cannot be empty');
                }

                const mapPath = this.constructMapPath();
                console.log(`Saving map to: ${mapPath}`);

                // ✅ CORRECT SERVICE TYPE dengan format yang benar
                const result = await this.saveMapWithStdMsgsFormat(mapPath);

                this.handleSaveSuccess(mapPath);

            } catch (error) {
                this.handleSaveError(error);
            } finally {
                this.isSavingMap = false;
            }
        },

        /**
         * ✅ CORRECT - Menggunakan std_msgs/String untuk field name
         */
        saveMapWithStdMsgsFormat(mapPath) {
            return new Promise((resolve, reject) => {
                // ✅ CORRECT SERVICE TYPE
                const saveMapService = new ROSLIB.Service({
                    ros: this.ros,
                    name: '/slam_toolbox/save_map',
                    serviceType: 'slam_toolbox/srv/SaveMap'
                });

                // ✅ CORRECT REQUEST FORMAT: menggunakan std_msgs/String
                const request = new ROSLIB.ServiceRequest({
                    name: new ROSLIB.Message({
                        data: mapPath  // ✅ std_msgs/String format
                    })
                });

                console.log('✅ Service Request (std_msgs/String):', request);

                saveMapService.callService(request, (result) => {
                    console.log('✅ Service Result:', result);
                    if (result !== undefined && result !== null) {
                        // Check result code based on interface
                        if (result.result === 0) {
                            resolve(result);
                        } else if (result.result === 1) {
                            reject(new Error('No map received - slam_toolbox might not be mapping'));
                        } else if (result.result === 255) {
                            reject(new Error('Undefined failure occurred'));
                        } else {
                            resolve(result); // Unknown result code but not an error
                        }
                    } else {
                        reject(new Error('Service returned undefined result'));
                    }
                }, (error) => {
                    console.error('❌ Service Error:', error);
                    reject(error);
                });
            });
        },

        constructMapPath() {
            let mapPath = this.mapSaveName.trim();

            // Remove extensions if present
            mapPath = mapPath.replace(/\.(yaml|pgm|png)$/i, '');

            // Gunakan directory yang sudah ditentukan
            let directory = this.mapSaveDirectory.trim();

            // Clean directory path
            if (directory.endsWith('/')) {
                directory = directory.slice(0, -1);
            }

            mapPath = `${directory}/${mapPath}`;

            console.log('Final map path:', mapPath);
            return mapPath;
        },

        handleSaveSuccess(mapPath) {
            this.lastSaveStatus = {
                type: 'success',
                icon: 'fas fa-check-circle',
                message: `✅ Map saved successfully to: ${mapPath}`
            };

            console.log('Map saved successfully:', mapPath);

            setTimeout(() => {
                if (this.lastSaveStatus?.type === 'success') {
                    this.lastSaveStatus = null;
                }
            }, 8000);
        },

        handleSaveError(error) {
            let errorMessage = 'Unknown error occurred';
            let showTroubleshooting = false;

            if (error.message.includes('FieldTypeMismatchException')) {
                errorMessage = 'Field type mismatch. Using std_msgs/String format...';
                // Auto-retry dengan format yang benar
                setTimeout(() => {
                    const mapPath = this.constructMapPath();
                    this.saveMapWithStdMsgsFormat(mapPath)
                        .then(() => this.handleSaveSuccess(mapPath))
                        .catch((retryError) => {
                            this.lastSaveStatus = {
                                type: 'error',
                                icon: 'fas fa-exclamation-circle',
                                message: `❌ Retry failed: ${retryError.message}`
                            };
                        });
                }, 2000);
                return;
            } else if (error.message.includes('No such file or directory')) {
                errorMessage = 'Directory not found. Please check the path.';
                showTroubleshooting = true;
            } else if (error.message.includes('Permission denied')) {
                errorMessage = 'Permission denied. Check directory permissions.';
                showTroubleshooting = true;
            } else if (error.message.includes('Service not found')) {
                errorMessage = 'Save map service not found. Check if slam_toolbox is running.';
                showTroubleshooting = true;
            } else if (error.message.includes('No map received')) {
                errorMessage = 'No map data received. Is slam_toolbox actively mapping?';
                showTroubleshooting = true;
            } else if (error.message.includes('Undefined failure')) {
                errorMessage = 'Undefined failure occurred. Check slam_toolbox logs.';
                showTroubleshooting = true;
            } else {
                errorMessage = `Save failed: ${error.message}`;
                showTroubleshooting = true;
            }

            this.lastSaveStatus = {
                type: 'error',
                icon: 'fas fa-exclamation-circle',
                message: `❌ ${errorMessage}`,
                showTroubleshooting: showTroubleshooting
            };

            console.error('Map save error:', error);
        },

        saveMapWithDialog() {
            const suggestedName = `polebot_map_${new Date().toISOString().slice(0, 10).replace(/-/g, '')}`;
            const mapName = prompt('Enter map name:', this.mapSaveName || suggestedName);

            if (mapName === null) return;

            if (!mapName.trim()) {
                alert('Map name cannot be empty!');
                return;
            }

            this.mapSaveName = mapName.trim();
            this.saveMapWithCorrectFormat();
        },

        quickSaveMap() {
            const timestamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-');
            this.mapSaveName = `polebot_quick_${timestamp}`;
            this.saveMapWithCorrectFormat();
        },

        /**
         * ✅ ENHANCED DEBUG untuk melihat service yang sebenarnya
         */
        async debugService() {
            if (!this.ros) {
                console.error('ROS not connected');
                return;
            }

            this.lastSaveStatus = {
                type: 'info',
                icon: 'fas fa-info-circle',
                message: 'Debugging service with actual interface...'
            };

            try {
                // Get all services
                const services = await new Promise((resolve, reject) => {
                    this.ros.getServices((services) => {
                        resolve(services);
                    }, (error) => {
                        reject(error);
                    });
                });

                console.log('Available services:', services);

                const saveMapAvailable = services.includes('/slam_toolbox/save_map');

                // Update service info berdasarkan interface yang sebenarnya
                this.serviceInfo = {
                    available: saveMapAvailable,
                    type: 'slam_toolbox/srv/SaveMap',
                    requestType: 'std_msgs/String name',
                    responseType: 'uint8 result (0=SUCCESS, 1=NO_MAP_RECEIVED, 255=UNDEFINED_FAILURE)',
                    details: 'Requires std_msgs/String for name field'
                };

                this.lastSaveStatus = {
                    type: 'success',
                    icon: 'fas fa-check-circle',
                    message: `✅ Debug complete. Service available: ${saveMapAvailable}`
                };

            } catch (error) {
                console.error('Debug error:', error);
                this.lastSaveStatus = {
                    type: 'error',
                    icon: 'fas fa-exclamation-circle',
                    message: `❌ Debug failed: ${error.message}`
                };
            }
        },

        loadGoals() {
            const input = document.createElement('input')
            input.type = 'file'
            input.accept = '.json'
            input.onchange = (e) => {
                const file = e.target.files[0]
                const reader = new FileReader()
                reader.onload = (e) => {
                    try {
                        const goals = JSON.parse(e.target.result)
                        this.$emit('update-goals', goals)
                        this.renderMap()
                    } catch (error) {
                        alert('Error loading goals file')
                    }
                }
                reader.readAsText(file)
            }
            input.click()
        },

        exportGoals() {
            this.saveGoals()
        },

        importGoals() {
            this.loadGoals()
        },

        addSampleGoals() {
            if (!this.mapInfo) return

            const sampleGoals = [
                { x: 1.0, y: 1.0, timestamp: Date.now(), id: Date.now() + 1 },
                { x: 2.0, y: 2.0, timestamp: Date.now() + 1, id: Date.now() + 2 },
                { x: 3.0, y: 1.0, timestamp: Date.now() + 2, id: Date.now() + 3 },
                { x: 2.0, y: 0.5, timestamp: Date.now() + 3, id: Date.now() + 4 }
            ]

            this.$emit('update-goals', [...this.goals, ...sampleGoals])
            this.renderMap()
        },

        zoomIn() {
            this.offset.scale = Math.min(this.offset.scale * 1.2, 3.0)
            this.renderMap()
        },

        zoomOut() {
            this.offset.scale = Math.max(this.offset.scale / 1.2, 0.5)
            this.renderMap()
        },

        resetView() {
            this.offset = { x: 0, y: 0, scale: 1.0 }
            this.renderMap()
        },

        centerMap() {
            this.offset = { x: 0, y: 0, scale: 1.0 }
            this.renderMap()
        },

        testConnection() {
            if (this.isConnected) {
                alert('✅ ROS connection is active')
            } else {
                alert('❌ ROS not connected')
            }
        },

        exportMapImage() {
            if (!this.mapData || !this.$refs.mapCanvas) return

            const canvas = this.$refs.mapCanvas
            const link = document.createElement('a')
            link.download = `nav2_map_${new Date().toISOString().slice(0, 10)}.png`
            link.href = canvas.toDataURL('image/png')
            link.click()
        },

        showHelp() {
            alert('🎯 Goal Planning Help:\n\n1. Click "Add Goal" mode\n2. Click on map to place goals\n3. Use right panel to manage goals\n4. Go to Mission Control to execute\n\n💡 Tips:\n- Hover over map to see coordinates\n- Click goal markers to remove\n- Save/Load goals from file')
        }
    }
}
</script>

<style scoped>
.goal-planning {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    gap: 20px;
}

/* Header Section */
.header-section {
    background: linear-gradient(135deg, rgba(30, 41, 59, 0.8), rgba(15, 23, 42, 0.9));
    border-radius: 16px;
    padding: 24px;
    border: 1px solid var(--border-color);
    display: flex;
    justify-content: space-between;
    align-items: center;
    backdrop-filter: blur(10px);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.header-content {
    display: flex;
    align-items: center;
    gap: 20px;
}

.header-icon {
    width: 60px;
    height: 60px;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 28px;
    color: white;
    box-shadow: 0 8px 16px rgba(59, 130, 246, 0.3);
}

.header-text h1 {
    margin: 0 0 8px 0;
    font-size: 28px;
    font-weight: 700;
    background: linear-gradient(135deg, var(--text-primary), var(--accent-blue));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}

.subtitle {
    margin: 0;
    font-size: 14px;
    color: var(--text-muted);
    max-width: 600px;
    line-height: 1.5;
}

.header-actions {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
}

.header-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 20px;
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    border-radius: 10px;
    font-weight: 500;
    transition: all 0.3s ease;
    min-width: 140px;
    justify-content: center;
}

.header-btn:hover:not(:disabled) {
    background-color: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
    color: var(--text-primary);
}

.header-btn.primary {
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    color: white;
    border: none;
}

.header-btn.primary:hover:not(:disabled) {
    box-shadow: 0 8px 20px rgba(59, 130, 246, 0.4);
    transform: translateY(-2px);
}

.header-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.input-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.input-label {
    display: flex;
    flex-direction: column;
    gap: 6px;
}

.label-text {
    font-weight: 600;
    color: var(--text-secondary);
    font-size: 14px;
}

.input-field {
    padding: 12px;
    border: 1px solid var(--border-color);
    background-color: rgba(255, 255, 255, 0.05);
    color: var(--text-primary);
    border-radius: 8px;
    font-size: 14px;
    transition: all 0.3s ease;
}

.input-field:focus {
    outline: none;
    border-color: var(--accent-blue);
    box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
}

.input-hint {
    font-size: 12px;
    color: var(--text-muted);
    margin-top: 4px;
}

/* Main Layout */
.main-layout {
    display: grid;
    grid-template-columns: 1fr 400px;
    gap: 24px;
    flex: 1;
    min-height: 0;
}

.map-section,
.goals-section {
    display: flex;
    flex-direction: column;
    gap: 20px;
}

/* Section Header */
.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
}

.section-title {
    display: flex;
    align-items: center;
    gap: 12px;
}

.title-icon {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    color: white;
}

.title-text h3 {
    margin: 0;
    font-size: 18px;
    font-weight: 600;
    color: var(--text-primary);
}

.section-subtitle {
    margin: 4px 0 0 0;
    font-size: 12px;
    color: var(--text-muted);
}

.section-controls {
    display: flex;
    gap: 16px;
}

.control-group {
    display: flex;
    flex-direction: column;
    gap: 8px;
}

.control-label {
    font-size: 12px;
    color: var(--text-muted);
    font-weight: 500;
}

.mode-buttons {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

.mode-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 16px;
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    transition: all 0.3s ease;
    min-height: 36px;
}

.mode-btn:hover {
    background-color: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
}

.mode-btn.active {
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    color: white;
    border: none;
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
}

.mode-btn.danger {
    background-color: rgba(239, 68, 68, 0.1);
    border-color: rgba(239, 68, 68, 0.3);
    color: var(--accent-red);
}

.mode-btn.danger:hover {
    background-color: rgba(239, 68, 68, 0.2);
}

/* Map Container */
.map-container {
    background-color: var(--card-bg);
    border-radius: 16px;
    border: 1px solid var(--border-color);
    padding: 20px;
    flex: 1;
    min-height: 400px;
    position: relative;
    overflow: hidden;
    box-shadow: 0 8px 32px var(--shadow-heavy);
}

.map-wrapper {
    position: relative;
    width: fit-content;
    margin: 0 auto;
}

.map-canvas {
    border: 2px solid var(--border-color);
    background-color: #2d3748;
    image-rendering: pixelated;
    max-width: 100%;
    height: auto;
    display: block;
    border-radius: 8px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
}

/* Goal Indicators */
.goal-indicator {
    position: absolute;
    width: 40px;
    height: 40px;
    cursor: pointer;
    z-index: 10;
    transform-origin: center;
    transition: transform 0.3s ease;
}

.goal-indicator:hover {
    transform: scale(1.2);
    z-index: 20;
}

.goal-marker {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, var(--accent-green), #22c55e);
    border: 3px solid #16a34a;
    border-radius: 50%;
    color: white;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    font-size: 14px;
    position: relative;
    box-shadow: 0 4px 12px rgba(16, 185, 129, 0.4);
}

.goal-pulse {
    position: absolute;
    width: 100%;
    height: 100%;
    border-radius: 50%;
    background: var(--accent-green);
    opacity: 0.6;
    animation: pulse-ring 2s infinite;
}

@keyframes pulse-ring {
    0% {
        transform: scale(0.8);
        opacity: 0.6;
    }

    70% {
        transform: scale(1.4);
        opacity: 0;
    }

    100% {
        transform: scale(1.4);
        opacity: 0;
    }
}

.goal-coordinates {
    position: absolute;
    top: 100%;
    left: 50%;
    transform: translateX(-50%);
    background-color: rgba(30, 41, 59, 0.95);
    color: white;
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 11px;
    white-space: nowrap;
    opacity: 0;
    transition: opacity 0.3s ease;
    pointer-events: none;
    border: 1px solid var(--border-color);
    z-index: 30;
}

.goal-indicator:hover .goal-coordinates {
    opacity: 1;
}

/* Map Controls Overlay */
.map-controls-overlay {
    position: absolute;
    top: 16px;
    right: 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    z-index: 5;
}

.map-control-btn {
    width: 36px;
    height: 36px;
    background-color: rgba(30, 41, 59, 0.9);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 14px;
    cursor: pointer;
    transition: all 0.3s ease;
    min-height: 36px;
}

.map-control-btn:hover {
    background-color: var(--accent-blue);
    color: white;
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
}

/* Map Legend */
.map-legend {
    position: absolute;
    bottom: 16px;
    left: 16px;
    background-color: rgba(30, 41, 59, 0.9);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 12px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    z-index: 5;
    backdrop-filter: blur(4px);
}

.legend-item {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
    color: var(--text-primary);
}

.legend-color {
    width: 16px;
    height: 16px;
    border-radius: 4px;
    border: 1px solid rgba(255, 255, 255, 0.2);
}

.legend-color.free {
    background-color: white;
}

.legend-color.occupied {
    background-color: black;
}

.legend-color.unknown {
    background-color: #808080;
}

.legend-color.goal {
    background-color: var(--accent-green);
}

/* Info Panel */
.info-panel {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 16px;
    padding: 20px;
    margin-top: 8px;
}

.info-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
    gap: 16px;
}

.info-card {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px;
    background-color: rgba(255, 255, 255, 0.03);
    border-radius: 10px;
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.3s ease;
}

.info-card:hover {
    background-color: rgba(255, 255, 255, 0.05);
    transform: translateY(-2px);
}

.info-icon {
    width: 36px;
    height: 36px;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 16px;
    color: white;
}

.info-content {
    flex: 1;
}

.info-label {
    font-size: 11px;
    color: var(--text-muted);
    font-weight: 500;
    margin-bottom: 2px;
}

.info-value {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-primary);
    font-family: 'Courier New', monospace;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

/* Goals Panel */
.goals-panel {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 16px;
    padding: 20px;
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
    box-shadow: 0 8px 32px var(--shadow-heavy);
}

.goals-count {
    display: flex;
    flex-direction: column;
    align-items: center;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    padding: 8px 16px;
    border-radius: 10px;
    color: white;
    min-width: 70px;
}

.count-number {
    font-size: 24px;
    font-weight: 700;
}

.count-label {
    font-size: 10px;
    opacity: 0.9;
    letter-spacing: 1px;
}

/* Empty State */
.empty-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 20px;
    text-align: center;
}

.empty-icon {
    width: 80px;
    height: 80px;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    border-radius: 20px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 36px;
    color: white;
    margin-bottom: 20px;
    opacity: 0.7;
}

.empty-state h4 {
    margin: 0 0 8px 0;
    font-size: 18px;
    color: var(--text-primary);
}

.empty-state p {
    margin: 0 0 20px 0;
    color: var(--text-muted);
    font-size: 14px;
    max-width: 300px;
}

.empty-actions {
    display: flex;
    gap: 12px;
    width: 100%;
    max-width: 300px;
}

.empty-actions .action-btn {
    flex: 1;
}

/* Goals List */
.goals-list {
    flex: 1;
    display: flex;
    flex-direction: column;
    min-height: 0;
}

.goals-list-header {
    display: grid;
    grid-template-columns: 50px 1fr 80px 100px;
    gap: 12px;
    padding: 12px 16px;
    background-color: rgba(255, 255, 255, 0.03);
    border-radius: 8px;
    margin-bottom: 8px;
    border: 1px solid rgba(255, 255, 255, 0.05);
}

.header-item {
    font-size: 11px;
    color: var(--text-muted);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.goals-list-content {
    flex: 1;
    overflow-y: auto;
    min-height: 0;
}

.goal-list-item {
    display: grid;
    grid-template-columns: 50px 1fr 80px 100px;
    gap: 12px;
    padding: 12px 16px;
    background-color: rgba(255, 255, 255, 0.03);
    border-radius: 8px;
    margin-bottom: 8px;
    border: 1px solid transparent;
    transition: all 0.3s ease;
    cursor: pointer;
    align-items: center;
}

.goal-list-item:hover {
    background-color: rgba(255, 255, 255, 0.05);
    border-color: rgba(255, 255, 255, 0.1);
    transform: translateX(4px);
}

.goal-list-item.active {
    background-color: rgba(59, 130, 246, 0.1);
    border-color: rgba(59, 130, 246, 0.3);
}

.goal-badge {
    width: 28px;
    height: 28px;
    background: linear-gradient(135deg, var(--accent-green), #22c55e);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: bold;
    color: white;
    margin: 0 auto;
}

.coord-display {
    display: flex;
    flex-direction: column;
    gap: 4px;
}

.coord-x,
.coord-y {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: var(--text-primary);
    font-family: 'Courier New', monospace;
    white-space: nowrap;
}

.coord-x i {
    color: var(--accent-red);
}

.coord-y i {
    color: var(--accent-green);
}

.time-display {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    color: var(--text-muted);
    white-space: nowrap;
}

.list-item-actions {
    display: flex;
    gap: 4px;
    align-items: center;
    justify-content: flex-end;
}

.list-action-btn {
    width: 28px;
    height: 28px;
    border: none;
    background-color: rgba(255, 255, 255, 0.05);
    color: var(--text-secondary);
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    transition: all 0.3s ease;
    flex-shrink: 0;
}

.list-action-btn:hover:not(:disabled) {
    background-color: var(--accent-blue);
    color: white;
    transform: translateY(-2px);
}

.list-action-btn.danger:hover:not(:disabled) {
    background-color: var(--accent-red);
}

.list-action-btn.success:hover:not(:disabled) {
    background-color: var(--accent-green);
}

.list-action-btn:disabled {
    opacity: 0.3;
    cursor: not-allowed;
}

/* Goals Actions */
.goals-actions {
    display: flex;
    flex-direction: column;
    gap: 16px;
    margin-top: 20px;
    padding-top: 20px;
    border-top: 1px solid var(--border-color);
}

.action-group {
    display: flex;
    gap: 12px;
    flex-wrap: wrap;
}

.action-btn {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 12px 20px;
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    border-radius: 10px;
    font-weight: 500;
    text-decoration: none;
    transition: all 0.3s ease;
    min-width: 120px;
    min-height: 44px;
}

.action-btn:hover:not(:disabled) {
    background-color: rgba(255, 255, 255, 0.1);
    transform: translateY(-2px);
    color: var(--text-primary);
}

.action-btn.primary {
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    color: white;
    border: none;
}

.action-btn.primary:hover:not(:disabled) {
    box-shadow: 0 8px 20px rgba(59, 130, 246, 0.4);
    transform: translateY(-2px);
}

.action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.action-btn.small {
    padding: 8px 12px;
    font-size: 13px;
    min-width: auto;
    min-height: 36px;
}

.btn-text {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

/* Current Goal Set Info */
.current-goal-set {
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 16px;
    margin-top: 8px;
}

.goal-set-info {
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.set-name, .map-name {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.set-name i {
    color: var(--accent-blue);
    flex-shrink: 0;
}

.map-name i {
    color: var(--accent-green);
    flex-shrink: 0;
}

.set-actions {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
}

/* Quick Actions Panel */
.quick-actions-panel {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 16px;
    padding: 20px;
    box-shadow: 0 8px 32px var(--shadow-heavy);
}

.quick-actions-content {
    transition: all 0.3s ease;
    width: 100%;
    overflow: hidden;
}

.quick-actions-content.collapsed {
    max-height: 0;
    opacity: 0;
    padding-top: 0;
    padding-bottom: 0;
    margin-top: 0;
}

.mobile-toggle {
    display: none;
    background: none;
    border: none;
    color: var(--text-muted);
    font-size: 16px;
    cursor: pointer;
    padding: 8px;
    border-radius: 6px;
    transition: all 0.3s ease;
    min-height: 40px;
    min-width: 40px;
    align-items: center;
    justify-content: center;
}

.mobile-toggle:hover {
    background: rgba(255, 255, 255, 0.05);
    color: var(--text-primary);
}

.quick-action-input {
    margin-bottom: 16px;
}

.quick-actions-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
}

.quick-action-btn {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px;
    background-color: rgba(255, 255, 255, 0.03);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    text-align: left;
    transition: all 0.3s ease;
    min-height: 70px;
}

.quick-action-btn:hover:not(:disabled) {
    background-color: rgba(255, 255, 255, 0.05);
    transform: translateY(-2px);
    border-color: var(--accent-blue);
}

.quick-action-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.action-icon {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 18px;
    color: white;
    flex-shrink: 0;
}

.action-text {
    flex: 1;
    min-width: 0;
}

.action-title {
    font-weight: 600;
    color: var(--text-primary);
    font-size: 14px;
    margin-bottom: 4px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.action-desc {
    font-size: 11px;
    color: var(--text-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

/* Responsive Design */
@media (max-width: 1200px) {
    .main-layout {
        grid-template-columns: 1fr;
    }

    .goals-section {
        max-height: none;
        min-height: 500px;
    }
}

@media (max-width: 768px) {
    .header-section {
        flex-direction: column;
        gap: 20px;
        align-items: stretch;
        padding: 16px;
    }

    .header-content {
        flex-direction: column;
        text-align: center;
        gap: 16px;
    }

    .header-actions {
        justify-content: center;
        width: 100%;
    }

    .header-btn {
        flex: 1;
        min-width: 140px;
    }

    .section-header {
        flex-direction: column;
        gap: 16px;
        align-items: stretch;
    }

    .section-controls {
        width: 100%;
    }

    .goals-count {
        align-self: center;
        margin-top: 10px;
    }

    .info-grid {
        grid-template-columns: 1fr;
    }

    .quick-actions-grid {
        grid-template-columns: 1fr;
    }

    .quick-actions-panel .section-header {
        flex-direction: row;
        align-items: center;
    }
    
    .mobile-toggle {
        display: flex;
    }

    /* Perbaikan untuk goals list di mobile */
    .goals-list-header {
        grid-template-columns: 40px 1fr 70px 90px;
        padding: 10px 12px;
        font-size: 10px;
    }

    .goal-list-item {
        grid-template-columns: 40px 1fr 70px 90px;
        padding: 10px 12px;
        gap: 8px;
    }

    .goal-badge {
        width: 24px;
        height: 24px;
        font-size: 11px;
    }

    .coord-display {
        gap: 2px;
    }

    .coord-x, .coord-y {
        font-size: 12px;
    }

    .time-display {
        font-size: 11px;
    }

    .list-action-btn {
        width: 26px;
        height: 26px;
        font-size: 11px;
    }

    /* Perbaikan untuk action buttons di mobile */
    .action-group {
        flex-direction: row;
        flex-wrap: wrap;
    }

    .action-btn {
        flex: 1 0 calc(50% - 6px);
        min-width: 0;
        padding: 10px 12px;
        font-size: 13px;
    }

    .btn-text {
        font-size: 12px;
    }

    /* Perbaikan untuk current goal set di mobile */
    .goal-set-info {
        flex-direction: column;
    }

    .set-name, .map-name {
        font-size: 13px;
    }

    .set-actions {
        justify-content: center;
    }

    .action-btn.small {
        flex: 1;
        min-width: 0;
    }
    
    /* Map Controls untuk Mobile */
    .map-controls-overlay {
        top: 10px;
        right: 10px;
        gap: 6px;
    }
    
    .map-control-btn {
        width: 40px;
        height: 40px;
        font-size: 16px;
    }
    
    .map-legend {
        bottom: 10px;
        left: 10px;
        padding: 10px;
        font-size: 11px;
    }
    
    .legend-item {
        gap: 6px;
    }
    
    .legend-color {
        width: 14px;
        height: 14px;
    }
}

@media (max-width: 480px) {
    .header-section {
        padding: 16px;
    }

    .header-icon {
        width: 50px;
        height: 50px;
        font-size: 22px;
    }

    .header-text h1 {
        font-size: 22px;
    }

    .subtitle {
        font-size: 13px;
    }

    .header-actions {
        flex-direction: column;
        width: 100%;
    }

    .header-btn {
        width: 100%;
        justify-content: center;
    }

    .main-layout {
        gap: 16px;
    }

    .map-section,
    .goals-section {
        gap: 16px;
    }

    .map-container {
        padding: 12px;
    }

    .goals-panel {
        padding: 16px;
    }

    .quick-actions-panel {
        padding: 16px;
    }

    /* Goals List untuk Mobile sangat kecil */
    .goals-list-header {
        grid-template-columns: 35px 1fr 65px;
        padding: 8px 10px;
        font-size: 9px;
    }
    
    .goal-list-item {
        grid-template-columns: 35px 1fr 65px;
        padding: 8px 10px;
        gap: 6px;
    }
    
    .header-item:nth-child(3),
    .list-item-time {
        display: none;
    }
    
    /* Make coordinates more compact */
    .coord-display {
        flex-direction: row;
        gap: 8px;
        flex-wrap: wrap;
    }
    
    .coord-x, .coord-y {
        font-size: 11px;
    }
    
    /* Empty State untuk Mobile */
    .empty-state {
        padding: 20px 16px;
    }
    
    .empty-icon {
        width: 60px;
        height: 60px;
        font-size: 24px;
        margin-bottom: 16px;
    }
    
    .empty-state h4 {
        font-size: 16px;
        margin-bottom: 6px;
    }
    
    .empty-state p {
        font-size: 13px;
        margin-bottom: 16px;
    }
    
    .empty-actions {
        flex-direction: column;
        width: 100%;
    }
    
    .empty-actions .action-btn {
        width: 100%;
    }
}

/* Mobile sangat kecil - adjust goals list */
@media (max-width: 380px) {
    .goals-list-header {
        grid-template-columns: 35px 1fr 60px 80px;
        font-size: 9px;
    }
    
    .goal-list-item {
        grid-template-columns: 35px 1fr 60px 80px;
    }
    
    .list-item-time {
        display: block;
    }
    
    .time-display {
        font-size: 10px;
    }
    
    .action-btn {
        flex: 1 0 100%;
    }
}

/* Tablet kecil landscape */
@media (max-height: 600px) and (orientation: landscape) {
    .goals-section {
        min-height: 300px;
    }
    
    .goals-list-content {
        max-height: 200px;
    }
}

/* Landscape orientation untuk mobile */
@media (max-width: 480px) and (orientation: landscape) {
    .goals-section {
        min-height: 250px;
    }
    
    .goals-list-content {
        max-height: 150px;
    }
}

/* Tambahan untuk button states di mobile */
@media (hover: none) {
    .action-btn:active,
    .header-btn:active,
    .mode-btn:active,
    .list-action-btn:active,
    .map-control-btn:active {
        transform: translateY(0);
        background-color: rgba(255, 255, 255, 0.1);
    }
    
    .action-btn.primary:active {
        background: linear-gradient(135deg, var(--accent-blue), var(--accent-purple));
        transform: translateY(0);
    }
}

/* Pastikan semua button tetap bisa diklik di mobile */
button:not(:disabled),
.action-btn:not(:disabled),
.header-btn:not(:disabled),
.mode-btn:not(:disabled),
.list-action-btn:not(:disabled) {
    cursor: pointer;
    -webkit-tap-highlight-color: transparent;
}

/* Improve touch targets for mobile */
@media (max-width: 768px) {
    button,
    .action-btn,
    .header-btn,
    .mode-btn,
    .list-action-btn {
        min-height: 44px;
    }
    
    .map-control-btn {
        width: 44px;
        height: 44px;
    }
}

/* Ensure buttons are always visible and clickable */
@media (max-width: 768px) {
    .goals-actions .action-group {
        display: flex !important;
        flex-wrap: wrap !important;
    }
    
    .goals-actions .action-btn {
        display: flex !important;
        visibility: visible !important;
        opacity: 1 !important;
        pointer-events: auto !important;
    }
}

/* Prevent text overflow */
.goal-list-item *,
.action-btn span,
.header-btn span,
.set-name,
.map-name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
</style>