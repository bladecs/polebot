<template>
  <div class="app-layout">
    <!-- Sidebar Navigation -->
    <div class="sidebar">
      <div class="sidebar-header">
        <h2>NAV2 Controller</h2>
      </div>
      <nav class="sidebar-nav">
        <router-link to="/dashboard" class="nav-item">
          <span class="nav-icon"><i class="fas fa-chart-bar"></i></span>
          <span class="nav-text">Dashboard</span>
        </router-link>
        <router-link to="/map" class="nav-item">
          <span class="nav-icon"><i class="fas fa-map"></i></span>
          <span class="nav-text">Map Controller</span>
        </router-link>
        <router-link to="/goals" class="nav-item">
          <span class="nav-icon"><i class="fas fa-bullseye"></i></span>
          <span class="nav-text">Goals Management</span>
        </router-link>
        <router-link to="/missions" class="nav-item">
          <span class="nav-icon"><i class="fas fa-rocket"></i></span>
          <span class="nav-text">Missions</span>
        </router-link>
        <router-link to="/settings" class="nav-item">
          <span class="nav-icon"><i class="fas fa-cog"></i></span>
          <span class="nav-text">Settings</span>
        </router-link>
        <router-link to="/logs" class="nav-item">
          <span class="nav-icon"><i class="fas fa-clipboard-list"></i></span>
          <span class="nav-text">System Logs</span>
        </router-link>
      </nav>
      <div class="sidebar-footer">
        <div class="connection-status">
          <div :class="['status-indicator', connectionStatus.class]"></div>
          <span>{{ connectionStatus.message }}</span>
        </div>
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="main-content">
      <!-- Top Navigation Bar -->
      <div class="navbar">
        <div class="navbar-left">
          <button class="menu-toggle" @click="toggleSidebar">
            <span class="menu-icon"><i class="fas fa-bars"></i></span>
          </button>
          <h1 class="page-title">{{ currentPageTitle }}</h1>
        </div>
        <div class="navbar-right">
          <div class="user-info">
            <span class="user-name">Operator</span>
            <div class="user-avatar"><i class="fas fa-user"></i></div>
          </div>
        </div>
      </div>

      <!-- Page Content -->
      <div class="content-area">
        <div class="nav2-map-controller">
          <!-- Header Section -->
          <div class="header-section">
            <h1>NAV2 Map Controller</h1>
            <p class="subtitle">PoleBot AMR Navigation System - ROS2 Jazzy Compatible</p>
          </div>

          <!-- Connection Status -->
          <div :class="['status', connectionStatus.class]">
            <div class="status-content">
              <span class="status-icon"><i :class="connectionStatus.icon"></i></span>
              <span>{{ connectionStatus.message }}</span>
            </div>
          </div>

          <!-- ROS2 Version Info -->
          <div class="ros-version-info">
            <div class="version-badge">ROS2 Jazzy</div>
            <div class="version-details">✅ Correct format: std_msgs/String for name field</div>
          </div>

          <!-- Main Layout: Map + Controls -->
          <div class="main-layout">
            <!-- Left Panel - Map Visualization -->
            <div class="map-section">
              <div class="panel-header">
                <div class="panel-title">
                  <span class="icon"><i class="fas fa-map"></i></span>
                  <h3>Navigation Map</h3>
                </div>
                <div class="map-controls">
                  <button @click="setAddGoalMode" :class="{ active: interactionMode === 'addGoal' }" class="mode-btn">
                    <span class="btn-icon"><i :class="interactionMode === 'addGoal' ? 'fas fa-check' : 'fas fa-bullseye'"></i></span>
                    <span class="btn-text">Add Goal</span>
                  </button>
                  <button @click="setViewMode" :class="{ active: interactionMode === 'view' }" class="mode-btn">
                    <span class="btn-icon"><i class="fas fa-eye"></i></span>
                    <span class="btn-text">View Only</span>
                  </button>
                  <button @click="clearAllGoals" class="clear-btn">
                    <span class="btn-icon"><i class="fas fa-trash"></i></span>
                    <span class="btn-text">Clear All</span>
                  </button>
                </div>
              </div>

              <!-- Interactive Map Canvas -->
              <div class="map-container">
                <canvas ref="mapCanvas" 
                        :width="canvasSize.width" 
                        :height="canvasSize.height" 
                        :style="getCanvasStyle()"
                        @click="handleMapClick">
                </canvas>

                <!-- Goal Markers Overlay -->
                <div v-for="(goal, index) in goals" 
                     :key="index" 
                     class="goal-indicator" 
                     :style="getGoalIndicatorStyle(goal)"
                     @click="removeGoal(index)" 
                     :title="getGoalTooltip(goal)">
                  <div class="goal-marker">{{ index + 1 }}</div>
                  <div class="goal-coord-display">
                    Web: ({{ goal.x.toFixed(1) }}, {{ goal.y.toFixed(1) }})<br>
                    RViz: ({{ getGoalForRViz(goal).x.toFixed(1) }}, {{ getGoalForRViz(goal).y.toFixed(1) }})
                  </div>
                </div>

                <!-- Coordinate Axes Reference -->
                <div class="coordinate-axes">
                  <div class="axis x-axis" :style="{ color: flipXCoordinate ? '#ff6b6b' : '#a8e6cf' }">
                    {{ flipXCoordinate ? '← X+ (Web) → X- (RViz)' : '→ X+ (Same)' }}
                  </div>
                  <div class="axis y-axis" :style="{ color: flipYCoordinate ? '#ff6b6b' : '#a8e6cf' }">
                    {{ flipYCoordinate ? '↑ Y+ (Web) → Y- (RViz)' : '↑ Y+ (Same)' }}
                  </div>
                </div>
              </div>

              <!-- Map Information Panel -->
              <div class="map-info">
                <div class="info-grid">
                  <div class="info-item">
                    <span class="info-label">Mode:</span>
                    <span class="info-value">{{ interactionMode === 'addGoal' ? 'Click map to add goals' : 'View only' }}</span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">Coordinate Flip:</span>
                    <span class="info-value">
                      X: <span :class="flipXCoordinate ? 'flip-active' : 'flip-inactive'">{{ flipXCoordinate ? 'FLIPPED' : 'Normal' }}</span>,
                      Y: <span :class="flipYCoordinate ? 'flip-active' : 'flip-inactive'">{{ flipYCoordinate ? 'FLIPPED' : 'Normal' }}</span>
                    </span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">Effect:</span>
                    <span class="info-value">{{ getFlipEffectDescription() }}</span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">Last Click:</span>
                    <span class="info-value" v-if="lastClickPosition">
                      Web ({{ lastClickPosition.mapX?.toFixed(2) || 'N/A' }}, {{ lastClickPosition.mapY?.toFixed(2) || 'N/A' }})
                      → RViz ({{ getGoalForRViz(lastClickPosition).x?.toFixed(2) || 'N/A' }}, {{
                        getGoalForRViz(lastClickPosition).y?.toFixed(2) || 'N/A' }})
                    </span>
                    <span class="info-value" v-else>No clicks yet</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Right Panel - Control Sections -->
            <div class="control-section">
              <!-- Save Map Configuration Panel -->
              <div class="control-panel">
                <div class="panel-header">
                  <div class="panel-title">
                    <span class="icon"><i class="fas fa-save"></i></span>
                    <h3>Save Map Configuration</h3>
                  </div>
                </div>
                
                <div class="save-controls">
                  <!-- Coordinate Flip Settings -->
                  <div class="flip-settings">
                    <h4>Coordinate Settings</h4>
                    <div class="flip-controls">
                      <label class="checkbox-label">
                        <input 
                          type="checkbox" 
                          v-model="flipXCoordinate"
                          class="checkbox-input"
                        >
                        <span class="checkmark"></span>
                        <span class="checkbox-text">Flip X Coordinate (Web +X → RViz -X)</span>
                      </label>
                      
                      <label class="checkbox-label">
                        <input 
                          type="checkbox" 
                          v-model="flipYCoordinate"
                          class="checkbox-input"
                        >
                        <span class="checkmark"></span>
                        <span class="checkbox-text">Flip Y Coordinate (Web +Y → RViz -Y)</span>
                      </label>
                    </div>
                    
                    <div class="coordinate-preview">
                      <div class="preview-title">Coordinate Preview:</div>
                      <div class="preview-content">
                        <div>Web: (1.0, 2.0) → RViz: ({{ flipXCoordinate ? '-1.0' : '1.0' }}, {{ flipYCoordinate ? '-2.0' : '2.0' }})</div>
                      </div>
                    </div>
                  </div>

                  <!-- Save Map Configuration -->
                  <div class="save-config">
                    <h4>Save Map Settings</h4>
                    
                    <div class="directory-info">
                      <div class="info-success">
                        <i class="fas fa-check-circle"></i>
                        <span>Using PoleBot directory: <code>~/polman-mbd-ros2-polebot-amr/src/polebot_amr_navigation/maps</code></span>
                      </div>
                    </div>
                    
                    <div class="input-group">
                      <label class="input-label">
                        <span class="label-text">Map Name:</span>
                        <input 
                          v-model="mapSaveName" 
                          type="text" 
                          placeholder="polebot_map" 
                          class="input-field"
                          :disabled="!isConnected || isSavingMap"
                        >
                        <div class="input-hint">File extensions (.yaml, .pgm) will be added automatically</div>
                      </label>
                    </div>
                    
                    <div class="input-group">
                      <label class="input-label">
                        <span class="label-text">Save Directory:</span>
                        <input 
                          v-model="mapSaveDirectory" 
                          type="text" 
                          class="input-field"
                          :disabled="!isConnected || isSavingMap"
                        >
                        <div class="input-hint">Maps will be saved to PoleBot navigation directory</div>
                      </label>
                    </div>
                    
                    <div class="save-buttons">
                      <button 
                        @click="saveMapWithCorrectFormat" 
                        :disabled="!isConnected || isSavingMap || !mapSaveName"
                        class="save-btn primary"
                      >
                        <span class="btn-icon">
                          <i v-if="isSavingMap" class="fas fa-spinner fa-spin"></i>
                          <i v-else class="fas fa-save"></i>
                        </span>
                        <span class="btn-text">
                          {{ isSavingMap ? 'Saving Map...' : 'Save Map' }}
                        </span>
                      </button>
                      
                      <button 
                        @click="saveMapWithDialog" 
                        :disabled="!isConnected || isSavingMap"
                        class="save-btn secondary"
                      >
                        <span class="btn-icon"><i class="fas fa-folder-open"></i></span>
                        <span class="btn-text">Save with Dialog</span>
                      </button>

                      <button 
                        @click="quickSaveMap" 
                        :disabled="!isConnected || isSavingMap"
                        class="save-btn secondary"
                      >
                        <span class="btn-icon"><i class="fas fa-bolt"></i></span>
                        <span class="btn-text">Quick Save</span>
                      </button>

                      <!-- Debug Button -->
                      <button 
                        @click="debugService" 
                        :disabled="!isConnected"
                        class="save-btn debug"
                      >
                        <span class="btn-icon"><i class="fas fa-bug"></i></span>
                        <span class="btn-text">Debug Service</span>
                      </button>
                    </div>
                    
                    <!-- Service Info Display -->
                    <div v-if="serviceInfo" class="service-info">
                      <div class="info-title">Service Information:</div>
                      <div class="info-content">
                        <div><strong>Type:</strong> {{ serviceInfo.type }}</div>
                        <div><strong>Available:</strong> {{ serviceInfo.available ? 'Yes' : 'No' }}</div>
                        <div><strong>Request Format:</strong> {{ serviceInfo.requestType }}</div>
                        <div><strong>Response Codes:</strong> {{ serviceInfo.responseType }}</div>
                      </div>
                    </div>
                    
                    <!-- Save Status Display -->
                    <div v-if="lastSaveStatus" :class="['save-status', lastSaveStatus.type]">
                      <span class="status-icon">
                        <i :class="lastSaveStatus.icon"></i>
                      </span>
                      <span class="status-message">{{ lastSaveStatus.message }}</span>
                    </div>

                    <!-- Troubleshooting Tips -->
                    <div v-if="lastSaveStatus && lastSaveStatus.type === 'error'" class="troubleshooting-tips">
                      <div class="tips-title">Troubleshooting Tips:</div>
                      <ul class="tips-list">
                        <li>Ensure slam_toolbox node is running</li>
                        <li>Check directory permissions</li>
                        <li>Try simple map names without spaces</li>
                        <li>Verify ROS2 bridge connection</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Map Information Panel -->
              <div class="control-panel">
                <div class="panel-header">
                  <div class="panel-title">
                    <span class="icon"><i class="fas fa-chart-bar"></i></span>
                    <h3>Map Information</h3>
                  </div>
                </div>
                <div class="info-grid">
                  <div class="info-item">
                    <span class="info-label">Size:</span>
                    <span class="info-value">{{ mapInfo?.width || 0 }} × {{ mapInfo?.height || 0 }} pixels</span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">Resolution:</span>
                    <span class="info-value">{{ (mapInfo?.resolution || 0).toFixed(4) }} m/pixel</span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">Origin:</span>
                    <span class="info-value">({{ mapInfo?.origin?.x || 0 }}, {{ mapInfo?.origin?.y || 0 }})</span>
                  </div>
                </div>
              </div>

              <!-- Goals List Panel -->
              <div class="control-panel">
                <div class="panel-header">
                  <div class="panel-title">
                    <span class="icon"><i class="fas fa-bullseye"></i></span>
                    <h3>Navigation Goals ({{ goals.length }})</h3>
                  </div>
                </div>
                <div v-if="goals.length === 0" class="no-goals">
                  <div class="no-goals-icon"><i class="fas fa-bullseye"></i></div>
                  <p>No goals set. Click on map in "Add Goal" mode to set goals.</p>
                </div>
                <div v-else class="goals-list">
                  <div v-for="(goal, index) in goals" :key="index" class="goal-item">
                    <div class="goal-info">
                      <div class="goal-header">
                        <span class="goal-number">#{{ index + 1 }}</span>
                        <div class="goal-timestamp">{{ formatTimestamp(goal.timestamp) }}</div>
                      </div>
                      <div class="goal-coord-comparison">
                        <div class="coord-web">Web: ({{ goal.x.toFixed(2) }}, {{ goal.y.toFixed(2) }})</div>
                        <div class="coord-rviz">RViz: ({{ getGoalForRViz(goal).x.toFixed(2) }}, {{
                          getGoalForRViz(goal).y.toFixed(2) }})</div>
                      </div>
                    </div>
                    <div class="goal-actions">
                      <button @click="sendSingleGoal(goal)" class="send-btn" title="Send this goal">
                        <span class="btn-icon"><i class="fas fa-paper-plane"></i></span>
                      </button>
                      <button @click="removeGoal(index)" class="remove-btn" title="Remove goal">
                        <span class="btn-icon"><i class="fas fa-trash"></i></span>
                      </button>
                    </div>
                  </div>
                </div>
              </div>
              
              <!-- Mission Control Panel -->
              <div class="control-panel">
                <div class="panel-header">
                  <div class="panel-title">
                    <span class="icon"><i class="fas fa-rocket"></i></span>
                    <h3>Mission Control</h3>
                  </div>
                </div>
                
                <!-- Mission Status Display -->
                <div class="mission-info" v-if="missionActive || missionStatus !== 'Ready'">
                  <div class="mission-state">
                    <strong>Status:</strong> {{ missionStatus }}
                  </div>
                  <div class="mission-progress-info">
                    <strong>Progress:</strong> {{ currentMissionGoal }} / {{ goals.length }} goals completed
                  </div>
                </div>
                
                <!-- Mission Control Buttons -->
                <div class="mission-buttons">
                  <button @click="startMission" 
                          :disabled="!isConnected || goals.length === 0 || missionActive"
                          class="mission-btn primary">
                    <span class="btn-icon"><i class="fas fa-rocket"></i></span>
                    <span class="btn-text">Start Sequential Mission</span>
                  </button>
                  <button @click="cancelMission" 
                          :disabled="!isConnected || !missionActive" 
                          class="cancel-btn">
                    <span class="btn-icon"><i class="fas fa-stop"></i></span>
                    <span class="btn-text">Cancel Mission</span>
                  </button>
                </div>

                <!-- Mission Progress Display -->
                <div v-if="missionActive && goals[currentMissionGoal]" class="mission-status">
                  <div class="mission-progress">
                    <div class="progress-bar">
                      <div class="progress-fill" :style="{ width: ((currentMissionGoal) / goals.length * 100) + '%' }"></div>
                    </div>
                    <div class="progress-text">Completed: {{ currentMissionGoal }} of {{ goals.length }} goals</div>
                    <div class="progress-text">Current: Goal {{ currentMissionGoal + 1 }}</div>
                  </div>
                </div>
              </div>

              <!-- Connection Control Panel -->
              <div class="control-panel">
                <div class="panel-header">
                  <div class="panel-title">
                    <span class="icon"><i class="fas fa-link"></i></span>
                    <h3>Connection</h3>
                  </div>
                </div>
                <div class="connection-controls">
                  <button @click="connectROS" :disabled="isConnected" class="connection-btn">
                    <span class="btn-icon"><i class="fas fa-plug"></i></span>
                    <span class="btn-text">Connect ROS</span>
                  </button>
                  <button @click="subscribeToMap" :disabled="!isConnected || isMapSubscribed" class="connection-btn">
                    <span class="btn-icon"><i class="fas fa-map"></i></span>
                    <span class="btn-text">Load Map</span>
                  </button>
                </div>
                <div class="connection-settings">
                  <label class="input-label">
                    <span class="label-text">ROS Bridge:</span>
                    <input v-model="rosBridgeUrl" 
                           type="text" 
                           placeholder="ws://localhost:9090" 
                           :disabled="isConnected" 
                           class="input-field" />
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ROSLIB from 'roslib';

export default {
  name: 'Nav2MapController',
  data() {
    return {
      // UI State
      currentPageTitle: 'Map Controller',
      
      // ROS Connection State
      ros: null,
      isConnected: false,
      isMapSubscribed: false,
      rosBridgeUrl: 'ws://localhost:9090',
      connectionStatus: {
        message: 'Disconnected',
        class: 'disconnected',
        icon: 'fas fa-circle'
      },

      // Map Data
      mapInfo: null,
      mapData: null,
      canvasSize: { width: 100, height: 100 },

      // Map Save Configuration
      mapSaveName: '',
      mapSaveDirectory: '~/polman-mbd-ros2-polebot-amr/src/polebot_amr_navigation/maps',
      isSavingMap: false,
      lastSaveStatus: null,
      serviceInfo: null,

      // Coordinate Configuration
      flipXCoordinate: false,
      flipYCoordinate: false,
      offset: { x: 0, y: 0, scale: 1.0 },

      // User Interaction
      interactionMode: 'addGoal',
      lastClickPosition: null,

      // Goals Management
      goals: [],

      // Mission Control
      missionActive: false,
      currentMissionGoal: 0,
      missionStatus: 'Ready',

      // Navigation State
      navigationStatus: {
        status: 'Idle',
        isActive: false,
        currentGoal: null
      },

      // ROS Topics
      mapTopic: null,
      goalTopic: null,
      saveMapService: null,
      navStatusTopic: null
    };
  },

  mounted() {
    this.connectROS();
    this.mapSaveName = `polebot_map_${new Date().toISOString().slice(0, 10).replace(/-/g, '')}_${this.getTimeStamp()}`;
  },

  methods: {
    // ==================== UI METHODS ====================
    
    toggleSidebar() {
      const sidebar = document.querySelector('.sidebar');
      sidebar.classList.toggle('collapsed');
    },

    setAddGoalMode() {
      this.interactionMode = 'addGoal';
    },

    setViewMode() {
      this.interactionMode = 'view';
    },

    // ==================== MAP SAVE FUNCTIONALITY ====================
    
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

    // ==================== MAP RENDERING ====================
    
    renderMapToCanvas(mapData) {
      const canvas = this.$refs.mapCanvas;
      if (!canvas) return;

      const ctx = canvas.getContext('2d');
      const width = mapData.info.width;
      const height = mapData.info.height;
      const data = mapData.data;

      ctx.clearRect(0, 0, width, height);
      const imageData = ctx.createImageData(width, height);

      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const index = y * width + x;
          const pixelIndex = index * 4;
          const cellValue = data[index];

          let r, g, b;
          if (cellValue === -1) {
            r = g = b = 128; // Unknown - gray
          } else if (cellValue === 0) {
            r = g = b = 255; // Free - white
          } else if (cellValue === 100) {
            r = g = b = 0;   // Occupied - black
          } else {
            r = 255; g = 200; b = 0; // Unknown - yellow
          }

          imageData.data[pixelIndex] = r;
          imageData.data[pixelIndex + 1] = g;
          imageData.data[pixelIndex + 2] = b;
          imageData.data[pixelIndex + 3] = 255;
        }
      }

      ctx.putImageData(imageData, 0, 0);
    },

    // ==================== COORDINATE CONVERSION ====================
    
    pixelToMapCoordinates(px, py) {
      if (!this.mapData || !this.mapInfo) return null;

      const origin = this.mapData.info.origin.position;
      const resolution = this.mapData.info.resolution;

      const adjustedPx = (px - this.offset.x) / this.offset.scale;
      const adjustedPy = (py - this.offset.y) / this.offset.scale;

      const mapX = origin.x + (adjustedPx * resolution);
      const mapY = origin.y + (adjustedPy * resolution);

      return { mapX, mapY };
    },

    calculatePixelCoordinates(mapX, mapY) {
      if (!this.mapData || !this.mapInfo) return { px: 0, py: 0 };

      const origin = this.mapData.info.origin.position;
      const resolution = this.mapData.info.resolution;
      const width = this.mapInfo.width;
      const height = this.mapInfo.height;

      const continuousX = (mapX - origin.x) / resolution;
      const continuousY = (mapY - origin.y) / resolution;

      const pixelX = Math.round(continuousX * this.offset.scale + this.offset.x);
      const pixelY = Math.round(continuousY * this.offset.scale + this.offset.y);

      return {
        px: Math.max(0, Math.min(pixelX, width - 1)),
        py: Math.max(0, Math.min(pixelY, height - 1))
      };
    },

    getGoalForRViz(goal) {
      if (!goal) return { x: 0, y: 0 };

      let rvizX = goal.x;
      let rvizY = goal.y;

      if (this.flipXCoordinate) rvizX = -goal.x;
      if (this.flipYCoordinate) rvizY = -goal.y;

      return { x: rvizX, y: rvizY, timestamp: goal.timestamp || Date.now() };
    },

    getFlipEffectDescription() {
      if (!this.flipXCoordinate && !this.flipYCoordinate) {
        return 'Web and RViz coordinates match exactly';
      } else if (this.flipXCoordinate && !this.flipYCoordinate) {
        return 'Web +X → RViz -X (X-axis flipped)';
      } else if (!this.flipXCoordinate && this.flipYCoordinate) {
        return 'Web +Y → RViz -Y (Y-axis flipped)';
      } else {
        return 'Web (X,Y) → RViz (-X,-Y) (Both axes flipped)';
      }
    },

    // ==================== GOALS MANAGEMENT ====================
    
    handleMapClick(event) {
      if (this.interactionMode !== 'addGoal' || !this.mapData || !this.mapInfo) return;

      const canvas = this.$refs.mapCanvas;
      const rect = canvas.getBoundingClientRect();
      const scale = 2 * this.offset.scale;

      const clickX = event.clientX - rect.left;
      const clickY = event.clientY - rect.top;

      const pixelX = Math.floor(clickX / scale);
      const pixelY = Math.floor(clickY / scale);

      const mapCoords = this.pixelToMapCoordinates(pixelX, pixelY);
      if (!mapCoords) return;

      this.lastClickPosition = {
        pixelX, pixelY,
        mapX: mapCoords.mapX,
        mapY: mapCoords.mapY
      };

      this.addGoal(mapCoords.mapX, mapCoords.mapY);
    },

    addGoal(x, y) {
      if (x === undefined || y === undefined) return;

      this.goals.push({ x, y, timestamp: Date.now() });
    },

    removeGoal(index) {
      if (this.missionActive && index === this.currentMissionGoal) {
        this.cancelMission();
      }
      this.goals.splice(index, 1);
    },

    clearAllGoals() {
      if (this.missionActive) this.cancelMission();
      this.goals = [];
    },

    // ==================== MISSION CONTROL ====================
    
    startMission() {
      if (!this.isConnected || this.goals.length === 0 || this.missionActive) return;

      this.missionActive = true;
      this.currentMissionGoal = 0;
      this.missionStatus = 'Mission Started';
      
      this.executeCurrentGoal();
    },

    executeCurrentGoal() {
      if (!this.missionActive || this.currentMissionGoal >= this.goals.length) {
        this.completeMission();
        return;
      }

      const goal = this.goals[this.currentMissionGoal];
      this.missionStatus = `Executing Goal ${this.currentMissionGoal + 1}/${this.goals.length}`;
      
      this.sendGoalViaTopic(goal);
    },

    sendGoalViaTopic(goal) {
      if (!this.isConnected || !goal) return;

      const rvizGoal = this.getGoalForRViz(goal);
      
      const goalMessage = new ROSLIB.Message({
        header: { 
          stamp: { 
            sec: Math.floor(Date.now() / 1000), 
            nanosec: (Date.now() % 1000) * 1000000 
          }, 
          frame_id: 'map' 
        },
        pose: {
          position: { x: rvizGoal.x, y: rvizGoal.y, z: 0.0 },
          orientation: { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
        }
      });

      try {
        this.goalTopic.publish(goalMessage);
        this.missionStatus = `Goal ${this.currentMissionGoal + 1} sent`;
        
        // Simulate goal completion after delay
        setTimeout(() => {
          if (this.missionActive) {
            this.handleGoalSuccess();
          }
        }, 3000);
      } catch (error) {
        console.error('Error sending mission goal:', error);
        this.handleGoalFailure();
      }
    },

    handleGoalSuccess() {
      this.currentMissionGoal++;
      
      if (this.currentMissionGoal < this.goals.length) {
        setTimeout(() => this.executeCurrentGoal(), 1000);
      } else {
        this.completeMission();
      }
    },

    handleGoalFailure() {
      this.missionStatus = `Failed at Goal ${this.currentMissionGoal + 1}`;
      this.missionActive = false;
    },

    completeMission() {
      this.missionActive = false;
      this.missionStatus = 'Mission Completed';
    },

    cancelMission() {
      this.missionActive = false;
      this.missionStatus = 'Cancelled';
    },

    // ==================== ROS INTEGRATION ====================
    
    connectROS() {
      this.ros = new ROSLIB.Ros({ 
        url: this.rosBridgeUrl 
      });

      this.ros.on('connection', () => {
        this.isConnected = true;
        this.updateStatus('✅ Connected to ROS Bridge!', 'connected', 'fas fa-check-circle');
        this.setupNav2Topics();
        this.subscribeToMap();
        
        // Debug service on connection
        setTimeout(() => {
          this.debugService();
        }, 1000);
      });

      this.ros.on('error', (error) => {
        this.isConnected = false;
        this.updateStatus('❌ Connection error: ' + error, 'error', 'fas fa-times-circle');
      });

      this.ros.on('close', () => {
        this.isConnected = false;
        this.updateStatus('⚠️ Connection closed', 'disconnected', 'fas fa-exclamation-circle');
      });
    },

    setupNav2Topics() {
      // Goal publishing topic
      this.goalTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/goal_pose',
        messageType: 'geometry_msgs/msg/PoseStamped'
      });
    },

    subscribeToMap() {
      if (!this.ros) return;

      this.mapTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/map',
        messageType: 'nav_msgs/msg/OccupancyGrid'
      });

      this.mapTopic.subscribe(this.handleMapMessage);
      this.isMapSubscribed = true;
    },

    handleMapMessage(mapData) {
      this.mapData = mapData;
      const origin = mapData.info.origin.position;

      this.mapInfo = {
        width: mapData.info.width,
        height: mapData.info.height,
        resolution: mapData.info.resolution,
        origin: { x: origin.x, y: origin.y }
      };

      this.canvasSize = { 
        width: mapData.info.width, 
        height: mapData.info.height 
      };

      this.$nextTick(() => this.renderMapToCanvas(mapData));
    },

    // ==================== UTILITY METHODS ====================
    
    getCanvasStyle() {
      return {
        width: (this.canvasSize.width * 2 * this.offset.scale) + 'px',
        height: (this.canvasSize.height * 2 * this.offset.scale) + 'px',
        cursor: this.interactionMode === 'addGoal' ? 'crosshair' : 'default'
      };
    },

    getGoalIndicatorStyle(goal) {
      if (!goal) return { left: '0px', top: '0px' };

      const pixelCoords = this.calculatePixelCoordinates(goal.x, goal.y);
      const scale = 2 * this.offset.scale;

      return {
        left: (pixelCoords.px * scale - 15) + 'px',
        top: (pixelCoords.py * scale - 15) + 'px'
      };
    },

    getGoalTooltip(goal) {
      if (!goal) return 'Goal: No data';
      const rvizGoal = this.getGoalForRViz(goal);
      return `Web(${goal.x.toFixed(2)}, ${goal.y.toFixed(2)}) → RViz(${rvizGoal.x.toFixed(2)}, ${rvizGoal.y.toFixed(2)})`;
    },

    formatTimestamp(timestamp) {
      if (!timestamp) return '';
      return new Date(timestamp).toLocaleTimeString();
    },

    updateStatus(message, statusClass, icon = '') {
      this.connectionStatus = { message, class: statusClass, icon };
    },

    sendSingleGoal(goal) {
      if (!this.isConnected || !goal) return;

      const rvizGoal = this.getGoalForRViz(goal);
      const goalMessage = new ROSLIB.Message({
        header: { 
          stamp: { 
            sec: Math.floor(Date.now() / 1000), 
            nanosec: (Date.now() % 1000) * 1000000 
          }, 
          frame_id: 'map' 
        },
        pose: {
          position: { x: rvizGoal.x, y: rvizGoal.y, z: 0.0 },
          orientation: { x: 0.0, y: 0.0, z: 0.0, w: 1.0 }
        }
      });

      try {
        this.goalTopic.publish(goalMessage);
        this.navigationStatus = { status: 'Single Goal Sent', isActive: true };
      } catch (error) {
        console.error('Error sending goal:', error);
      }
    }
  }
};
</script>

<style scoped>
/* CSS Variables */
:root {
  --primary-dark: #1a1a2e;
  --primary-medium: #16213e;
  --primary-light: #0f3460;
  --card-bg: #2d3748;
  --border-color: #4a5568;
  --text-primary: #e2e8f0;
  --text-secondary: #a0aec0;
  --text-muted: #718096;
  --accent-primary: #4a90e2;
  --accent-success: #48bb78;
  --accent-warning: #ecc94b;
  --accent-danger: #f56565;
  --hover-light: rgba(255, 255, 255, 0.05);
  --shadow-light: rgba(0, 0, 0, 0.1);
  --shadow-medium: rgba(0, 0, 0, 0.3);
}

/* Main Layout */
.app-layout {
  display: flex;
  height: 100vh;
  background-color: var(--primary-dark);
  color: var(--text-primary);
  overflow: hidden;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
}

/* Sidebar */
.sidebar {
  width: 250px;
  background-color: var(--card-bg);
  border-right: 1px solid var(--border-color);
  display: flex;
  flex-direction: column;
  transition: width 0.3s ease;
  flex-shrink: 0;
}

.sidebar.collapsed {
  width: 60px;
}

.sidebar-header {
  padding: 20px;
  border-bottom: 1px solid var(--border-color);
}

.sidebar-header h2 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.sidebar-nav {
  flex: 1;
  padding: 10px 0;
}

.nav-item {
  display: flex;
  align-items: center;
  padding: 12px 20px;
  color: var(--text-secondary);
  text-decoration: none;
  transition: all 0.2s ease;
  border-left: 3px solid transparent;
}

.nav-item:hover {
  background-color: var(--hover-light);
  color: var(--text-primary);
}

.nav-item.router-link-active {
  background-color: var(--primary-medium);
  color: var(--accent-primary);
  border-left-color: var(--accent-primary);
}

.nav-icon {
  font-size: 18px;
  margin-right: 12px;
  width: 20px;
  text-align: center;
}

.nav-text {
  font-weight: 500;
}

.sidebar-footer {
  padding: 15px 20px;
  border-top: 1px solid var(--border-color);
}

.connection-status {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
}

.status-indicator {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.status-indicator.connected {
  background-color: #4CAF50;
}

.status-indicator.error {
  background-color: #F44336;
}

.status-indicator.disconnected {
  background-color: #FFC107;
}

/* Main Content Area */
.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Navbar */
.navbar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 20px;
  height: 60px;
  background-color: var(--card-bg);
  border-bottom: 1px solid var(--border-color);
  flex-shrink: 0;
}

.navbar-left {
  display: flex;
  align-items: center;
  gap: 15px;
}

.menu-toggle {
  background: none;
  border: none;
  color: var(--text-primary);
  font-size: 18px;
  cursor: pointer;
  padding: 5px;
  border-radius: 4px;
  transition: background-color 0.2s ease;
}

.menu-toggle:hover {
  background-color: var(--hover-light);
}

.page-title {
  margin: 0;
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
}

.navbar-right {
  display: flex;
  align-items: center;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-name {
  font-weight: 500;
}

.user-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background-color: var(--primary-medium);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
}

/* Content Area */
.content-area {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
  background-color: var(--primary-dark);
}

/* NAV2 Map Controller Styles */
.nav2-map-controller {
  width: 100%;
  height: 100%;
}

.header-section {
  text-align: center;
  margin-bottom: 20px;
  padding: 20px;
  background: linear-gradient(135deg, var(--primary-medium), var(--primary-light));
  border-radius: 10px;
  box-shadow: 0 4px 12px var(--shadow-medium);
}

.header-section h1 {
  margin: 0 0 8px 0;
  font-size: 28px;
  font-weight: 600;
  color: var(--text-primary);
}

.subtitle {
  margin: 0;
  font-size: 16px;
  color: var(--text-secondary);
}

/* ROS2 Version Info */
.ros-version-info {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  background-color: rgba(74, 144, 226, 0.15);
  border-radius: 6px;
  margin-bottom: 15px;
  border-left: 4px solid var(--accent-primary);
}

.version-badge {
  background-color: var(--accent-primary);
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
}

.version-details {
  font-size: 12px;
  color: var(--text-secondary);
}

.status {
  padding: 12px 16px;
  border-radius: 8px;
  margin: 10px 0;
  font-weight: 500;
  box-shadow: 0 2px 4px var(--shadow-light);
  border-left: 4px solid;
}

.status.connected {
  background-color: rgba(76, 175, 80, 0.15);
  color: #4CAF50;
  border-left-color: #4CAF50;
}

.status.error {
  background-color: rgba(244, 67, 54, 0.15);
  color: #F44336;
  border-left-color: #F44336;
}

.status.disconnected {
  background-color: rgba(255, 193, 7, 0.15);
  color: #FFC107;
  border-left-color: #FFC107;
}

.status-content {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-icon {
  font-size: 18px;
}

.main-layout {
  display: grid;
  grid-template-columns: 1fr 400px;
  gap: 20px;
  margin-top: 20px;
}

.map-section {
  background-color: var(--card-bg);
  padding: 20px;
  border-radius: 10px;
  border: 1px solid var(--border-color);
  box-shadow: 0 4px 8px var(--shadow-light);
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 15px;
  border-bottom: 1px solid var(--border-color);
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.panel-title h3 {
  margin: 0;
  color: var(--text-primary);
  font-size: 18px;
  font-weight: 600;
}

.icon {
  font-size: 20px;
}

.map-controls {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

.mode-btn, .clear-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border: 1px solid var(--border-color);
  background-color: var(--primary-medium);
  color: var(--text-primary);
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
  transition: all 0.2s ease;
}

.mode-btn:hover, .clear-btn:hover {
  background-color: var(--hover-light);
  transform: translateY(-1px);
}

.mode-btn.active {
  background-color: var(--accent-primary);
  border-color: var(--accent-primary);
}

.clear-btn {
  background-color: rgba(244, 67, 54, 0.2);
  border-color: var(--accent-danger);
}

.clear-btn:hover {
  background-color: rgba(244, 67, 54, 0.3);
}

.btn-icon {
  font-size: 14px;
}

.btn-text {
  font-weight: 500;
}

.map-container {
  position: relative;
  display: inline-block;
  margin-bottom: 20px;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 4px 8px var(--shadow-medium);
}

.map-container canvas {
  border: 1px solid var(--border-color);
  background-color: #666;
  image-rendering: pixelated;
  max-width: 100%;
  height: auto;
  display: block;
}

.goal-indicator {
  position: absolute;
  width: 30px;
  height: 30px;
  cursor: pointer;
  z-index: 5;
}

.goal-marker {
  width: 30px;
  height: 30px;
  background-color: var(--accent-success);
  border: 3px solid #1e7e34;
  border-radius: 50%;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 12px;
  transition: transform 0.2s;
  box-shadow: 0 2px 4px var(--shadow-medium);
}

.goal-indicator:hover .goal-marker {
  transform: scale(1.2);
  background-color: #20c997;
}

.coordinate-axes {
  position: absolute;
  bottom: 10px;
  left: 10px;
  pointer-events: none;
  z-index: 10;
}

.axis {
  background: rgba(0, 0, 0, 0.7);
  color: white;
  padding: 4px 8px;
  border-radius: 4px;
  font-size: 10px;
  margin-bottom: 5px;
  font-weight: 500;
}

.map-info {
  background-color: var(--primary-medium);
  padding: 15px;
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.info-grid {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.info-item:last-child {
  border-bottom: none;
}

.info-label {
  font-weight: 600;
  color: var(--text-secondary);
  font-size: 14px;
}

.info-value {
  font-size: 14px;
  text-align: right;
  color: var(--text-primary);
}

.flip-active {
  color: #ff6b6b;
  font-weight: 600;
}

.flip-inactive {
  color: #a8e6cf;
  font-weight: 500;
}

.control-section {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.control-panel {
  background-color: var(--card-bg);
  padding: 20px;
  border-radius: 10px;
  border: 1px solid var(--border-color);
  box-shadow: 0 4px 8px var(--shadow-light);
}

/* Save Map Controls Styling */
.save-controls {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.flip-settings, .save-config {
  padding: 15px;
  background-color: var(--primary-medium);
  border-radius: 8px;
  border: 1px solid var(--border-color);
}

.flip-settings h4, .save-config h4 {
  margin: 0 0 12px 0;
  color: var(--text-primary);
  font-size: 16px;
  font-weight: 600;
}

.flip-controls {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 15px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 10px;
  cursor: pointer;
  padding: 8px;
  border-radius: 4px;
  transition: background-color 0.2s ease;
}

.checkbox-label:hover {
  background-color: var(--hover-light);
}

.checkbox-input {
  display: none;
}

.checkmark {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border-color);
  border-radius: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
}

.checkbox-input:checked + .checkmark {
  background-color: var(--accent-primary);
  border-color: var(--accent-primary);
}

.checkbox-input:checked + .checkmark::after {
  content: '✓';
  color: white;
  font-size: 12px;
  font-weight: bold;
}

.checkbox-text {
  font-size: 14px;
  color: var(--text-primary);
}

.coordinate-preview {
  padding: 10px;
  background-color: rgba(0, 0, 0, 0.2);
  border-radius: 4px;
  font-family: 'Courier New', monospace;
}

.preview-title {
  font-weight: 600;
  margin-bottom: 5px;
  color: var(--text-secondary);
  font-size: 12px;
}

.preview-content {
  font-size: 13px;
  color: var(--text-primary);
}

.save-config {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.directory-info {
  margin-bottom: 15px;
}

.info-success {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px;
  background-color: rgba(40, 167, 69, 0.15);
  border: 1px solid rgba(40, 167, 69, 0.3);
  border-radius: 6px;
  color: #28a745;
  font-size: 13px;
}

.info-success i {
  font-size: 16px;
}

.info-success code {
  background-color: rgba(0, 0, 0, 0.2);
  padding: 2px 6px;
  border-radius: 3px;
  font-family: 'Courier New', monospace;
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.input-hint {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 4px;
  font-style: italic;
}

.save-buttons {
  display: flex;
  gap: 10px;
  margin-top: 10px;
  flex-wrap: wrap;
}

.save-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 600;
  font-size: 14px;
  transition: all 0.2s ease;
  min-width: 120px;
}

.save-btn.primary {
  background-color: var(--accent-success);
  color: white;
}

.save-btn.primary:hover:not(:disabled) {
  background-color: #218838;
  transform: translateY(-1px);
}

.save-btn.secondary {
  background-color: var(--primary-light);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
}

.save-btn.secondary:hover:not(:disabled) {
  background-color: var(--hover-light);
  transform: translateY(-1px);
}

.save-btn.debug {
  background-color: var(--accent-warning);
  color: #212529;
}

.save-btn.debug:hover:not(:disabled) {
  background-color: #e0a800;
  transform: translateY(-1px);
}

.save-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none !important;
}

.service-info {
  padding: 12px;
  background-color: rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  margin-top: 10px;
  border-left: 4px solid var(--accent-primary);
}

.info-title {
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--text-primary);
  font-size: 14px;
}

.info-content {
  font-size: 12px;
  color: var(--text-secondary);
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.info-content div {
  font-family: 'Courier New', monospace;
  background: rgba(0, 0, 0, 0.3);
  padding: 4px 6px;
  border-radius: 3px;
}

.save-status {
  padding: 10px;
  border-radius: 6px;
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
}

.save-status.success {
  background-color: rgba(40, 167, 69, 0.15);
  color: #28a745;
  border: 1px solid rgba(40, 167, 69, 0.3);
}

.save-status.error {
  background-color: rgba(220, 53, 69, 0.15);
  color: #dc3545;
  border: 1px solid rgba(220, 53, 69, 0.3);
}

.save-status.warning {
  background-color: rgba(255, 193, 7, 0.15);
  color: #ffc107;
  border: 1px solid rgba(255, 193, 7, 0.3);
}

.save-status.info {
  background-color: rgba(23, 162, 184, 0.15);
  color: #17a2b8;
  border: 1px solid rgba(23, 162, 184, 0.3);
}

.status-icon {
  font-size: 16px;
}

.status-message {
  font-weight: 500;
}

.troubleshooting-tips {
  margin-top: 15px;
  padding: 12px;
  background-color: rgba(108, 117, 125, 0.15);
  border-radius: 6px;
  border-left: 4px solid #6c757d;
}

.tips-title {
  font-weight: 600;
  margin-bottom: 8px;
  color: var(--text-primary);
  font-size: 14px;
}

.tips-list {
  margin: 0;
  padding-left: 20px;
  font-size: 13px;
  color: var(--text-secondary);
}

.tips-list li {
  margin-bottom: 4px;
}

.tips-list code {
  background-color: rgba(0, 0, 0, 0.2);
  padding: 2px 4px;
  border-radius: 3px;
  font-family: 'Courier New', monospace;
  font-size: 12px;
}

/* Mission Info Styles */
.mission-info {
  background-color: var(--primary-medium);
  padding: 10px;
  border-radius: 6px;
  margin-bottom: 15px;
  font-size: 14px;
}

.mission-state, .mission-progress-info {
  margin-bottom: 5px;
}

.mission-state {
  color: var(--accent-primary);
}

.mission-progress-info {
  color: var(--text-secondary);
}

.goals-list {
  max-height: 250px;
  overflow-y: auto;
  margin-top: 10px;
}

.goal-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  margin: 8px 0;
  background-color: var(--primary-medium);
  border-radius: 6px;
  border: 1px solid var(--border-color);
  transition: all 0.2s ease;
}

.goal-item:hover {
  background-color: var(--hover-light);
  transform: translateY(-1px);
}

.goal-info {
  flex: 1;
}

.goal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}

.goal-number {
  font-weight: bold;
  color: var(--accent-success);
  font-size: 14px;
}

.goal-timestamp {
  font-size: 11px;
  color: var(--text-muted);
}

.goal-coord-comparison {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.coord-web, .coord-rviz {
  font-family: 'Courier New', monospace;
  font-size: 12px;
}

.coord-web {
  color: var(--text-secondary);
}

.coord-rviz {
  color: var(--accent-primary);
}

.goal-actions {
  display: flex;
  gap: 6px;
}

.send-btn, .remove-btn {
  padding: 6px 10px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 12px;
  transition: all 0.2s ease;
}

.send-btn {
  background-color: rgba(74, 144, 226, 0.2);
  color: var(--accent-primary);
}

.send-btn:hover {
  background-color: rgba(74, 144, 226, 0.3);
}

.remove-btn {
  background-color: rgba(244, 67, 54, 0.2);
  color: var(--accent-danger);
}

.remove-btn:hover {
  background-color: rgba(244, 67, 54, 0.3);
}

.no-goals {
  text-align: center;
  color: var(--text-muted);
  padding: 30px 20px;
}

.no-goals-icon {
  font-size: 40px;
  margin-bottom: 10px;
  opacity: 0.5;
}

.mission-buttons {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 15px;
}

.mission-btn, .cancel-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 600;
  font-size: 14px;
  transition: all 0.2s ease;
}

.mission-btn.primary {
  background-color: var(--accent-warning);
  color: #212529;
}

.mission-btn.primary:hover:not(:disabled) {
  background-color: #e0a800;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px var(--shadow-light);
}

.cancel-btn {
  background-color: rgba(244, 67, 54, 0.2);
  color: var(--accent-danger);
}

.cancel-btn:hover:not(:disabled) {
  background-color: rgba(244, 67, 54, 0.3);
  transform: translateY(-1px);
}

.mission-status {
  margin-top: 15px;
  padding: 12px;
  background-color: var(--primary-medium);
  border-radius: 6px;
  border-left: 4px solid var(--accent-primary);
}

.mission-progress {
  margin-bottom: 10px;
}

.progress-bar {
  height: 6px;
  background-color: var(--primary-light);
  border-radius: 3px;
  overflow: hidden;
  margin-bottom: 6px;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--accent-primary), #6ab0ff);
  border-radius: 3px;
  transition: width 0.3s ease;
}

.progress-text {
  font-size: 12px;
  color: var(--text-secondary);
  text-align: center;
}

.connection-controls {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
}

.connection-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 10px;
  border: 1px solid var(--border-color);
  background-color: var(--primary-medium);
  color: var(--text-primary);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.connection-btn:hover:not(:disabled) {
  background-color: var(--hover-light);
  transform: translateY(-1px);
}

.connection-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.connection-settings {
  margin-top: 10px;
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
  padding: 10px;
  border: 1px solid var(--border-color);
  background-color: var(--primary-medium);
  color: var(--text-primary);
  border-radius: 6px;
  font-size: 14px;
}

.input-field:focus {
  outline: none;
  border-color: var(--accent-primary);
  box-shadow: 0 0 0 2px rgba(74, 144, 226, 0.2);
}

.input-field:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none !important;
}

button:not(:disabled):hover {
  opacity: 0.9;
}

/* Scrollbar styling */
.goals-list::-webkit-scrollbar {
  width: 6px;
}

.goals-list::-webkit-scrollbar-track {
  background: var(--primary-medium);
  border-radius: 3px;
}

.goals-list::-webkit-scrollbar-thumb {
  background: var(--border-color);
  border-radius: 3px;
}

.goals-list::-webkit-scrollbar-thumb:hover {
  background: var(--text-muted);
}

/* Responsive design */
@media (max-width: 1024px) {
  .main-layout {
    grid-template-columns: 1fr;
  }
  
  .control-section {
    order: -1;
  }
}

@media (max-width: 768px) {
  .sidebar {
    width: 60px;
  }
  
  .nav-text {
    display: none;
  }
  
  .sidebar-header h2 {
    display: none;
  }
  
  .sidebar.collapsed {
    width: 60px;
  }
  
  .content-area {
    padding: 10px;
  }
  
  .panel-header {
    flex-direction: column;
    gap: 15px;
    align-items: flex-start;
  }
  
  .map-controls {
    width: 100%;
    justify-content: space-between;
  }
  
  .mission-buttons, .connection-controls, .save-buttons {
    flex-direction: column;
  }
  
  .info-item {
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }
  
  .info-value {
    text-align: left;
  }

  .flip-controls {
    gap: 8px;
  }
  
  .checkbox-text {
    font-size: 13px;
  }

  .save-btn {
    min-width: 100%;
  }
}

@media (max-width: 480px) {
  .navbar {
    padding: 0 10px;
  }
  
  .page-title {
    font-size: 16px;
  }
  
  .header-section h1 {
    font-size: 22px;
  }
  
  .subtitle {
    font-size: 14px;
  }
  
  .control-panel {
    padding: 15px;
  }
  
  .save-controls {
    gap: 15px;
  }
  
  .flip-settings, .save-config {
    padding: 12px;
  }
}
</style>