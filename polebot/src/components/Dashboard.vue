<template>
  <div class="nav2-map-controller">
    <h2>NAV2 Map Controller - With Coordinate Calibration</h2>
    
    <div :class="['status', connectionStatus.class]">
      {{ connectionStatus.message }}
    </div>

    <div class="main-layout">
      <!-- Left Panel - Map -->
      <div class="map-section">
        <div class="map-header">
          <h3>🗺️ Navigation Map</h3>
          <div class="map-controls">
            <button @click="setAddGoalMode" :class="{ active: interactionMode === 'addGoal' }" class="mode-btn">
              {{ interactionMode === 'addGoal' ? '✅ Add Goal' : '🎯 Add Goal' }}
            </button>
            <button @click="setViewMode" :class="{ active: interactionMode === 'view' }" class="mode-btn">
              👁️ View Only
            </button>
            <button @click="clearAllGoals" class="clear-btn">🗑️ Clear All</button>
          </div>
        </div>

        <div class="map-container">
          <canvas 
            ref="mapCanvas" 
            :width="canvasSize.width" 
            :height="canvasSize.height"
            :style="{
              width: canvasSize.width * 2 + 'px',
              height: canvasSize.height * 2 + 'px',
              cursor: interactionMode === 'addGoal' ? 'crosshair' : 'default'
            }"
            @click="handleMapClick"
          ></canvas>
          
          <!-- Robot indicator -->
          <div 
            v-if="robotPose && mapInfo" 
            class="robot-indicator"
            :style="getRobotIndicatorStyle()"
          >
            <div class="robot-arrow"></div>
            <div class="robot-dot"></div>
          </div>

          <!-- Goal indicators -->
          <div 
            v-for="(goal, index) in goals" 
            :key="index"
            class="goal-indicator"
            :style="getGoalIndicatorStyle(goal)"
            @click="removeGoal(index)"
            :title="`Goal ${index + 1}: (${goal.x.toFixed(2)}, ${goal.y.toFixed(2)}) - Click to remove`"
          >
            <div class="goal-marker">{{ index + 1 }}</div>
          </div>
        </div>

        <div class="map-info">
          <p><strong>Mode:</strong> {{ interactionMode === 'addGoal' ? 'Click map to add goals' : 'View only' }}</p>
          <p v-if="lastClickPosition">
            <strong>Last Click:</strong> ({{ lastClickPosition.mapX.toFixed(2) }}, {{ lastClickPosition.mapY.toFixed(2) }})
          </p>
          <p v-if="missionActive">
            <strong>Mission Progress:</strong> {{ currentMissionGoal + 1 }}/{{ goals.length }}
          </p>
          <p v-if="missionActive">
            <strong>Status:</strong> {{ missionStatus }}
          </p>
          <p v-if="stuckCounter > 0">
            <strong>Stuck Detection:</strong> {{ stuckCounter }}/10
          </p>
          <p>
            <strong>Y Offset:</strong> {{ yOffset }}
          </p>
        </div>
      </div>

      <!-- Right Panel - Controls -->
      <div class="control-section">
        <!-- Map Information -->
        <div class="info-panel">
          <h3>📊 Map Information</h3>
          <p><strong>Size:</strong> {{ mapInfo?.width || 0 }} × {{ mapInfo?.height || 0 }} pixels</p>
          <p><strong>Resolution:</strong> {{ (mapInfo?.resolution || 0).toFixed(4) }} m/pixel</p>
          <p><strong>Origin:</strong> ({{ mapInfo?.origin?.x || 0 }}, {{ mapInfo?.origin?.y || 0 }})</p>
        </div>

        <!-- Robot Information -->
        <div v-if="robotPose" class="robot-panel">
          <h3>🤖 Robot Position</h3>
          <p><strong>Position:</strong> ({{ robotPose.x.toFixed(3) }}, {{ robotPose.y.toFixed(3) }})</p>
          <p><strong>Orientation:</strong> {{ robotPose.thetaDeg.toFixed(1) }}°</p>
          <button @click="addCurrentPoseAsGoal" class="add-btn">Add Current Pose as Goal</button>
        </div>

        <!-- Goals List -->
        <div class="goals-panel">
          <h3>🎯 Navigation Goals ({{ goals.length }})</h3>
          <div v-if="goals.length === 0" class="no-goals">
            <p>No goals set. Click on map in "Add Goal" mode to set goals.</p>
          </div>
          <div v-else class="goals-list">
            <div v-for="(goal, index) in goals" :key="index" class="goal-item" :class="{ 
              active: missionActive && currentMissionGoal === index,
              completed: index < currentMissionGoal 
            }">
              <div class="goal-info">
                <span class="goal-number">#{{ index + 1 }}</span>
                <span class="goal-coords">({{ goal.x.toFixed(2) }}, {{ goal.y.toFixed(2) }})</span>
                <span v-if="missionActive && currentMissionGoal === index" class="goal-status active">🟢 Active</span>
                <span v-else-if="index < currentMissionGoal" class="goal-status completed">✅ Completed</span>
                <span v-else class="goal-status">⏳ Pending</span>
              </div>
              <div class="goal-actions">
                <button @click="sendSingleGoal(goal)" class="send-btn" title="Send this goal">➡️</button>
                <button @click="removeGoal(index)" class="remove-btn" title="Remove goal">🗑️</button>
              </div>
            </div>
          </div>
        </div>

        <!-- Mission Controls -->
        <div class="mission-panel">
          <h3>🚀 Mission Control</h3>
          <div class="mission-status-indicator" :class="getMissionStatusClass()">
            {{ missionStatus }}
          </div>
          <div class="mission-buttons">
            <button 
              @click="startMission" 
              :disabled="!isConnected || goals.length === 0 || missionActive" 
              class="mission-btn primary"
            >
              {{ missionActive ? `Mission Running (${currentMissionGoal + 1}/${goals.length})` : `Start Sequential Mission` }}
            </button>
            <button 
              @click="sendCurrentGoal" 
              :disabled="!isConnected || goals.length === 0 || missionActive" 
              class="mission-btn"
            >
              Send Current Goal Only
            </button>
            <button 
              @click="manualRecovery" 
              :disabled="!isConnected || !missionActive" 
              class="mission-btn recovery-btn"
            >
              Manual Recovery
            </button>
            <button 
              @click="checkGoalActivationManually" 
              :disabled="!isConnected" 
              class="mission-btn debug-btn"
            >
              Debug Status
            </button>
            <button 
              @click="cancelMission" 
              :disabled="!isConnected || !missionActive" 
              class="cancel-btn"
            >
              Cancel Mission
            </button>
          </div>
        </div>

        <!-- Navigation Status -->
        <div class="status-panel">
          <h3>📈 Navigation Status</h3>
          <div class="status-info">
            <p><strong>State:</strong> 
              <span :class="getStatusClass(navigationStatus.status)">
                {{ navigationStatus.status }}
              </span>
            </p>
            <p><strong>Active:</strong> {{ navigationStatus.isActive ? 'Yes' : 'No' }}</p>
            <p><strong>Mission:</strong> {{ missionActive ? 'Running' : 'Stopped' }}</p>
            <p><strong>Current Goal:</strong> #{{ currentMissionGoal + 1 }} of {{ goals.length }}</p>
            <p v-if="navigationStatus.feedback">
              <strong>Feedback:</strong> {{ navigationStatus.feedback }}
            </p>
            <p v-if="navigationStatus.error">
              <strong>Error:</strong> <span class="error-text">{{ navigationStatus.error }}</span>
            </p>
          </div>
        </div>

        <!-- Connection & Calibration Controls -->
        <div class="connection-panel">
          <h3>🔗 Connection & Calibration</h3>
          <div class="connection-controls">
            <button @click="connectROS" :disabled="isConnected">Connect ROS</button>
            <button @click="subscribeToMap" :disabled="!isConnected || isMapSubscribed">Load Map</button>
            <button @click="subscribeToRobotPose" :disabled="!isConnected || isRobotSubscribed">Track Robot</button>
            <button @click="debugCoordinateConversion" :disabled="!isConnected" class="calibration-btn">Debug Coordinates</button>
            <button @click="autoCalibrateYOffset" :disabled="!isConnected" class="calibration-btn">Auto-Calibrate Y Offset</button>
          </div>
          <div class="calibration-controls">
            <label>
              Manual Y Offset:
              <input v-model.number="yOffset" type="number" :disabled="!isConnected" />
              <button @click="adjustYOffset(-1)" :disabled="!isConnected" class="adjust-btn">-</button>
              <button @click="adjustYOffset(1)" :disabled="!isConnected" class="adjust-btn">+</button>
            </label>
          </div>
          <div class="connection-settings">
            <label>
              ROS Bridge:
              <input v-model="rosBridgeUrl" type="text" placeholder="ws://localhost:9090" :disabled="isConnected" />
            </label>
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
      ros: null,
      isConnected: false,
      isMapSubscribed: false,
      isRobotSubscribed: false,
      rosBridgeUrl: 'ws://localhost:9090',
      
      // Map data
      mapInfo: null,
      mapData: null,
      canvasSize: { width: 100, height: 100 },
      
      // Interaction
      interactionMode: 'addGoal',
      lastClickPosition: null,
      yOffset: 17, // Default value, akan di-calibrate
      
      // Goals and robot
      goals: [],
      robotPose: null,
      previousRobotPose: null,
      
      // Mission control - SEQUENTIAL SYSTEM dengan Stuck Recovery
      missionActive: false,
      missionPaused: false,
      currentMissionGoal: 0,
      missionStatus: 'Ready',
      isWaitingForCompletion: false,
      stuckCounter: 0,
      lastRobotPosition: null,
      missionStartTime: null,
      
      // Navigation
      navigationStatus: {
        status: 'Idle',
        isActive: false,
        feedback: null,
        error: null,
        lastGoalCompleted: false
      },
      
      // ROS objects
      mapTopic: null,
      robotPoseTopic: null,
      goalTopic: null,
      cancelTopic: null,
      feedbackTopic: null,
      resultTopic: null,
      statusTopic: null,
      
      connectionStatus: {
        message: 'Disconnected',
        class: 'disconnected'
      }
    };
  },
  methods: {
    connectROS() {
      this.ros = new ROSLIB.Ros({
        url: this.rosBridgeUrl
      });

      this.ros.on('connection', () => {
        this.isConnected = true;
        this.updateStatus('✅ Connected to ROS Bridge!', 'connected');
        this.setupNav2Topics();
        console.log('Connected to ROS Bridge');
      });

      this.ros.on('error', (error) => {
        this.isConnected = false;
        this.updateStatus('❌ Connection error: ' + error, 'error');
        console.error('ROS connection error:', error);
      });

      this.ros.on('close', () => {
        this.isConnected = false;
        this.updateStatus('⚠️ Connection closed', 'disconnected');
        console.log('ROS connection closed');
      });
    },

    setupNav2Topics() {
      console.log('Setting up NAV2 Topics...');
      
      // Topic untuk mengirim goal
      this.goalTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/goal_pose',
        messageType: 'geometry_msgs/msg/PoseStamped'
      });

      // Cancel topic
      this.cancelTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/navigate_to_pose/_action/cancel_goal',
        messageType: 'action_msgs/msg/CancelGoal'
      });

      // Subscribe to navigation feedback
      this.feedbackTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/navigate_to_pose/_action/feedback',
        messageType: 'nav2_msgs/action/NavigateToPose_FeedbackMessage'
      });

      this.feedbackTopic.subscribe((message) => {
        if (message && message.feedback) {
          const feedback = message.feedback;
          this.navigationStatus.feedback = `Distance: ${feedback.distance_remaining?.toFixed(2) || 'N/A'}m`;
          this.navigationStatus.status = 'Navigating';
          this.navigationStatus.isActive = true;
        }
      });

      // Subscribe to result
      this.resultTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/navigate_to_pose/_action/result',
        messageType: 'nav2_msgs/action/NavigateToPose_ResultMessage'
      });

      this.resultTopic.subscribe((message) => {
        console.log('Navigation Result Received:', message);
        if (message && message.result) {
          this.navigationStatus.status = 'Goal Completed';
          this.navigationStatus.isActive = false;
          this.navigationStatus.feedback = 'Goal reached successfully';
          this.navigationStatus.lastGoalCompleted = true;
          this.updateStatus('✅ Goal completed!', 'connected');
          
          // Jika mission aktif, lanjut ke goal berikutnya
          if (this.missionActive && this.isWaitingForCompletion) {
            console.log('🎯 Goal completed via result topic, proceeding to next goal');
            this.isWaitingForCompletion = false;
            this.stuckCounter = 0;
            this.goToNextGoal();
          }
        }
      });

      // Subscribe to status
      this.statusTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/navigate_to_pose/_action/status',
        messageType: 'action_msgs/msg/GoalStatusArray'
      });

      this.statusTopic.subscribe((message) => {
        if (message && message.status_list && message.status_list.length > 0) {
          const status = message.status_list[0];
          
          switch (status.status) {
            case 1: // ACTIVE
              this.navigationStatus.status = 'Navigating to Goal';
              this.navigationStatus.isActive = true;
              this.navigationStatus.error = null;
              this.navigationStatus.lastGoalCompleted = false;
              this.missionStatus = 'Moving to goal...';
              break;
            case 4: // SUCCEEDED
              this.navigationStatus.status = 'Goal Completed';
              this.navigationStatus.isActive = false;
              this.navigationStatus.lastGoalCompleted = true;
              this.missionStatus = 'Goal reached!';
              break;
            case 2: // PREEMPTED
              this.navigationStatus.status = 'Goal Cancelled';
              this.navigationStatus.isActive = false;
              this.missionStatus = 'Goal cancelled';
              break;
            case 3: // ABORTED
              this.navigationStatus.status = 'Goal Failed';
              this.navigationStatus.isActive = false;
              this.navigationStatus.error = 'Navigation failed';
              this.missionStatus = 'Goal failed';
              if (this.missionActive) {
                this.cancelMission();
              }
              break;
            case 5: // EXECUTING
            case 6: // EXECUTING
              this.navigationStatus.status = 'Navigating to Goal';
              this.navigationStatus.isActive = true;
              this.navigationStatus.error = null;
              this.navigationStatus.lastGoalCompleted = false;
              this.missionStatus = 'Executing...';
              break;
          }
        }
      });
    },

    subscribeToMap() {
      if (!this.ros) return;

      if (this.mapTopic) this.mapTopic.unsubscribe();

      this.mapTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/map',
        messageType: 'nav_msgs/msg/OccupancyGrid'
      });

      this.mapTopic.subscribe(this.handleMapMessage);
      this.isMapSubscribed = true;
      this.updateStatus('🗺️ Map subscribed', 'connected');
    },

    subscribeToRobotPose() {
      if (!this.ros) return;

      if (this.robotPoseTopic) this.robotPoseTopic.unsubscribe();

      this.robotPoseTopic = new ROSLIB.Topic({
        ros: this.ros,
        name: '/amcl_pose',
        messageType: 'geometry_msgs/msg/PoseWithCovarianceStamped'
      });

      this.robotPoseTopic.subscribe(this.handleRobotPoseMessage);
      this.isRobotSubscribed = true;
      this.updateStatus('🤖 Robot tracking started', 'connected');
    },

    handleMapMessage(mapData) {
      console.log('Map data received');
      this.mapData = mapData;
      
      const origin = mapData.info.origin.position;
      const resolution = mapData.info.resolution;
      const width = mapData.info.width;
      const height = mapData.info.height;

      this.mapInfo = {
        width: width,
        height: height,
        resolution: resolution,
        origin: { x: origin.x, y: origin.y }
      };

      this.canvasSize = { width: width, height: height };

      this.$nextTick(() => {
        this.renderMapToCanvas(mapData);
      });
    },

    handleRobotPoseMessage(poseMessage) {
      this.previousRobotPose = this.robotPose;

      const pose = poseMessage.pose.pose;
      const position = pose.position;
      const orientation = pose.orientation;
      
      const theta = this.quaternionToYaw(orientation);
      const thetaDeg = theta * (180 / Math.PI);

      this.robotPose = {
        x: position.x,
        y: position.y,
        z: position.z,
        theta: theta,
        thetaDeg: thetaDeg,
        orientation: orientation
      };
    },

    // COORDINATE CALIBRATION METHODS
    debugCoordinateConversion() {
      if (!this.mapData || !this.mapInfo) {
        console.log('❌ No map data available');
        return;
      }

      const origin = this.mapData.info.origin.position;
      const resolution = this.mapData.info.resolution;
      const width = this.mapInfo.width;
      const height = this.mapInfo.height;

      console.log('🔍 COORDINATE CONVERSION DEBUG:');
      console.log('- Map Origin:', origin);
      console.log('- Resolution:', resolution);
      console.log('- Map Size:', width, 'x', height);
      console.log('- Y Offset:', this.yOffset);
      
      // Test conversion untuk beberapa titik
      const testPoints = [
        { px: 0, py: 0 },
        { px: Math.floor(width/2), py: Math.floor(height/2) },
        { px: width-1, py: height-1 }
      ];

      testPoints.forEach((point, index) => {
        const mapCoords = this.pixelToMapCoordinates(point.px, point.py);
        console.log(`- Test Point ${index + 1}:`);
        console.log(`  Pixel: (${point.px}, ${point.py})`);
        console.log(`  Map: (${mapCoords?.mapX.toFixed(3)}, ${mapCoords?.mapY.toFixed(3)})`);
      });

      // Test reverse conversion
      if (this.robotPose) {
        const pixelCoords = this.calculatePixelCoordinates(this.robotPose.x, this.robotPose.y);
        console.log('- Robot Position Conversion:');
        console.log(`  World: (${this.robotPose.x.toFixed(3)}, ${this.robotPose.y.toFixed(3)})`);
        console.log(`  Pixel: (${pixelCoords.px}, ${pixelCoords.py})`);
        
        // Test goal conversion jika ada goals
        if (this.goals.length > 0) {
          console.log('- Goal Position Conversion:');
          this.goals.forEach((goal, index) => {
            const goalPixels = this.calculatePixelCoordinates(goal.x, goal.y);
            console.log(`  Goal ${index + 1}: World (${goal.x.toFixed(3)}, ${goal.y.toFixed(3)}) -> Pixel (${goalPixels.px}, ${goalPixels.py})`);
          });
        }
      }
    },

    autoCalibrateYOffset() {
      if (!this.robotPose || !this.mapData) {
        console.log('❌ Cannot calibrate: no robot pose or map data');
        return;
      }

      console.log('🎯 Starting Y-offset auto-calibration...');
      
      // Convert robot position to pixel coordinates dengan berbagai offset
      const testOffsets = [-20, -15, -10, -5, 0, 5, 10, 15, 17, 20, 25, 30];
      let bestOffset = this.yOffset;
      let minError = Infinity;

      testOffsets.forEach(offset => {
        const tempYOffset = this.yOffset;
        this.yOffset = offset;
        
        const pixelCoords = this.calculatePixelCoordinates(this.robotPose.x, this.robotPose.y);
        
        // Calculate error (distance dari center of map)
        const errorX = Math.abs(pixelCoords.px - this.mapInfo.width / 2);
        const errorY = Math.abs(pixelCoords.py - this.mapInfo.height / 2);
        const totalError = errorX + errorY;
        
        console.log(`- Offset ${offset}: error = ${totalError.toFixed(2)}, pixel = (${pixelCoords.px}, ${pixelCoords.py})`);
        
        if (totalError < minError) {
          minError = totalError;
          bestOffset = offset;
        }
        
        this.yOffset = tempYOffset; // Reset
      });

      console.log(`✅ Best Y-offset: ${bestOffset} (error: ${minError.toFixed(2)})`);
      this.yOffset = bestOffset;
      this.updateStatus(`🎯 Y-offset auto-calibrated to: ${bestOffset}`, 'connected');
      
      // Re-render map dengan offset baru
      if (this.mapData) {
        this.$nextTick(() => {
          this.renderMapToCanvas(this.mapData);
        });
      }
    },

    adjustYOffset(delta) {
      this.yOffset += delta;
      console.log(`🔧 Y-offset adjusted to: ${this.yOffset}`);
      this.updateStatus(`🔧 Y-offset manually adjusted to: ${this.yOffset}`, 'connected');
      
      // Re-render map jika perlu
      if (this.mapData) {
        this.$nextTick(() => {
          this.renderMapToCanvas(this.mapData);
        });
      }
    },

    setAddGoalMode() {
      this.interactionMode = 'addGoal';
    },

    setViewMode() {
      this.interactionMode = 'view';
    },

    handleMapClick(event) {
      if (this.interactionMode !== 'addGoal' || !this.mapData || !this.mapInfo) return;
      
      const canvas = this.$refs.mapCanvas;
      const rect = canvas.getBoundingClientRect();
      const scale = 2;
      
      const clickX = event.clientX - rect.left;
      const clickY = event.clientY - rect.top;
      
      const pixelX = Math.floor(clickX / scale);
      const pixelY = Math.floor(clickY / scale);
      
      const mapCoords = this.pixelToMapCoordinates(pixelX, pixelY);
      
      if (!mapCoords) return;

      console.log(`🎯 Click: Pixel (${pixelX}, ${pixelY}) -> World (${mapCoords.mapX.toFixed(3)}, ${mapCoords.mapY.toFixed(3)})`);

      this.addGoal(mapCoords.mapX, mapCoords.mapY);
      
      this.lastClickPosition = {
        pixelX,
        pixelY,
        mapX: mapCoords.mapX,
        mapY: mapCoords.mapY
      };
    },

    addGoal(x, y, orientationZ = 0.0, orientationW = 1.0) {
      this.goals.push({
        x: x,
        y: y,
        z: orientationZ,
        w: orientationW,
        timestamp: Date.now()
      });
      
      this.updateStatus(`🎯 Goal #${this.goals.length} added at (${x.toFixed(2)}, ${y.toFixed(2)})`, 'connected');
    },

    addCurrentPoseAsGoal() {
      if (this.robotPose) {
        this.addGoal(
          this.robotPose.x,
          this.robotPose.y,
          this.robotPose.orientation.z,
          this.robotPose.orientation.w
        );
      }
    },

    removeGoal(index) {
      if (this.missionActive && index === this.currentMissionGoal) {
        this.cancelMission();
      }
      this.goals.splice(index, 1);
      this.updateStatus(`🗑️ Goal #${index + 1} removed`, 'connected');
    },

    clearAllGoals() {
      if (this.missionActive) {
        this.cancelMission();
      }
      this.goals = [];
      this.updateStatus('🗑️ All goals cleared', 'connected');
    },

    // COORDINATE CONVERSION METHODS
    calculatePixelCoordinates(mapX, mapY) {
      if (!this.mapData || !this.mapInfo) return { px: 0, py: 0 };
      
      const origin = this.mapData.info.origin.position;
      const resolution = this.mapData.info.resolution;
      const width = this.mapInfo.width;
      const height = this.mapInfo.height;

      // Convert world coordinates to continuous pixel coordinates
      const continuousX = (mapX - origin.x) / resolution;
      const continuousY = (mapY - origin.y) / resolution;

      // Convert to integer pixel coordinates
      // Y-axis in image is inverted compared to world coordinates
      const pixelX = Math.round(continuousX);
      const pixelY = height - Math.round(continuousY) - 1;

      // Apply Y offset correction
      const adjustedPixelY = pixelY + this.yOffset;

      return {
        px: Math.max(0, Math.min(pixelX, width - 1)),
        py: Math.max(0, Math.min(adjustedPixelY, height - 1))
      };
    },

    pixelToMapCoordinates(px, py) {
      if (!this.mapData || !this.mapInfo) return null;
      
      const origin = this.mapData.info.origin.position;
      const resolution = this.mapData.info.resolution;
      const height = this.mapInfo.height;
      
      // Remove Y offset first
      const originalPy = py - this.yOffset;
      
      // Convert pixel coordinates to world coordinates
      // Y-axis in image is inverted compared to world coordinates
      const mapX = origin.x + (px * resolution);
      const mapY = origin.y + ((height - originalPy - 1) * resolution);
      
      return { mapX, mapY };
    },

    // SEQUENTIAL MISSION SYSTEM dengan STUCK RECOVERY - FIXED VERSION
    async startMission() {
      if (!this.isConnected || this.goals.length === 0 || this.missionActive) return;

      this.missionActive = true;
      this.currentMissionGoal = 0;
      this.missionStatus = 'Starting mission...';
      this.navigationStatus.lastGoalCompleted = false;
      this.stuckCounter = 0;
      this.missionStartTime = Date.now();
      
      this.updateStatus(`🚀 Starting sequential mission with ${this.goals.length} goals`, 'connected');

      // Start dengan goal pertama
      await this.executeCurrentGoalSequentially();
    },

    async executeCurrentGoalSequentially() {
      // ✅ FIX: Validasi mission state sebelum eksekusi
      if (!this.missionActive || this.currentMissionGoal >= this.goals.length) {
        console.log('❌ Invalid mission state, stopping');
        this.cancelMission();
        return;
      }

      const goal = this.goals[this.currentMissionGoal];
      console.log(`🎯 SEQUENTIAL: Executing goal ${this.currentMissionGoal + 1}/${this.goals.length}`, goal);
      
      this.missionStatus = `Sending goal ${this.currentMissionGoal + 1}...`;
      this.updateStatus(`🎯 Mission: Goal ${this.currentMissionGoal + 1}/${this.goals.length}`, 'connected');

      // Reset status sebelum mengirim goal
      this.navigationStatus = {
        status: 'Goal Sent',
        isActive: false,
        feedback: null,
        error: null,
        lastGoalCompleted: false
      };

      // Kirim goal dan tunggu completion
      await this.sendGoalAndWait(goal);
    },

    async sendGoalAndWait(goal) {
      return new Promise((resolve) => {
        console.log('📤 Sending goal and waiting for completion...');
        
        // Reset stuck detection variables
        this.stuckCounter = 0;
        this.lastRobotPosition = null;
        let isResolved = false;
        
        // Kirim goal
        this.sendSingleGoal(goal);
        
        // Set flag bahwa kita sedang menunggu completion
        this.isWaitingForCompletion = true;
        this.missionStatus = 'Waiting for goal completion...';

        // ✅ FIX: Enhanced stuck detection dengan priority completion check
        const checkStuckCondition = () => {
          if (!this.robotPose || !this.goals[this.currentMissionGoal] || !this.isWaitingForCompletion || isResolved) return;
          
          const currentGoal = this.goals[this.currentMissionGoal];
          const distanceToGoal = Math.sqrt(
            Math.pow(this.robotPose.x - currentGoal.x, 2) +
            Math.pow(this.robotPose.y - currentGoal.y, 2)
          );

          // ✅ FIX 1: CHECK COMPLETION FIRST - PRIORITY!
          if (distanceToGoal < 0.15) {
            console.log(`🎯 Goal ${this.currentMissionGoal + 1} completed during stuck check! Distance: ${distanceToGoal.toFixed(3)}m`);
            this.navigationStatus.lastGoalCompleted = true;
            this.isWaitingForCompletion = false;
            this.stuckCounter = 0;
            isResolved = true;
            clearTimeout(timeout);
            clearInterval(stuckCheckInterval);
            clearInterval(positionCheckInterval);
            setTimeout(() => {
              this.goToNextGoal();
              resolve(true);
            }, 500);
            return;
          }

          const currentPosition = { x: this.robotPose.x, y: this.robotPose.y };
          
          if (this.lastRobotPosition) {
            const distanceMoved = Math.sqrt(
              Math.pow(currentPosition.x - this.lastRobotPosition.x, 2) +
              Math.pow(currentPosition.y - this.lastRobotPosition.y, 2)
            );
            
            console.log(`🔄 Distance moved since last check: ${distanceMoved.toFixed(3)}m`);
            
            // ✅ FIX 2: IMPROVED STUCK DETECTION - hanya stuck jika jauh dari goal
            if (distanceMoved < 0.03 && distanceToGoal > 0.10) {
              this.stuckCounter++;
              console.log(`⚠️ Stuck counter: ${this.stuckCounter}/10`);
              
              if (this.stuckCounter >= 10) {
                console.log('🚨 ROBOT STUCK DETECTED! Attempting recovery...');
                this.missionStatus = 'Robot stuck, attempting recovery...';
                this.handleStuckRecovery(resolve);
                return;
              }
            } else {
              // Reset stuck counter jika robot bergerak atau dekat goal
              this.stuckCounter = Math.max(0, this.stuckCounter - 1);
            }
          }
          
          this.lastRobotPosition = currentPosition;
        };

        // Timeout handler
        const timeout = setTimeout(() => {
          if (!isResolved && this.isWaitingForCompletion) {
            console.log('⏰ Goal timeout, checking final position...');
            this.checkPositionAndProceed(resolve, true);
          }
        }, 45000); // 45 detik timeout

        // Completion handler dari result topic
        const resultHandler = (message) => {
          if (!isResolved && this.isWaitingForCompletion && message && message.result) {
            console.log('✅ Goal completed via result topic');
            isResolved = true;
            clearTimeout(timeout);
            clearInterval(stuckCheckInterval);
            clearInterval(positionCheckInterval);
            this.isWaitingForCompletion = false;
            this.stuckCounter = 0;
            this.resultTopic.unsubscribe(resultHandler);
            resolve(true);
          }
        };

        // Listen untuk result
        this.resultTopic.subscribe(resultHandler);

        // Stuck detection interval (setiap 2 detik)
        const stuckCheckInterval = setInterval(() => {
          if (!this.isWaitingForCompletion || isResolved) {
            clearInterval(stuckCheckInterval);
            return;
          }
          checkStuckCondition();
        }, 2000);

        // Position check interval (setiap 3 detik)
        const positionCheckInterval = setInterval(() => {
          if (!this.isWaitingForCompletion || isResolved) {
            clearInterval(positionCheckInterval);
            return;
          }
          this.checkPositionAndProceed(resolve, false);
        }, 3000);

        // Initial stuck check setup
        setTimeout(() => {
          if (this.robotPose && this.isWaitingForCompletion && !isResolved) {
            this.lastRobotPosition = { x: this.robotPose.x, y: this.robotPose.y };
          }
        }, 1000);
      });
    },

    async handleStuckRecovery(resolve) {
      console.log('🔄 Starting stuck recovery procedure...');
      this.missionStatus = 'Robot stuck, starting recovery...';
      
      // ✅ FIX: Validasi mission state
      if (!this.missionActive || this.currentMissionGoal >= this.goals.length) {
        console.log('❌ Invalid mission state in recovery');
        if (resolve) resolve(false);
        return;
      }
      
      const currentGoal = this.goals[this.currentMissionGoal];
      console.log('🔄 Recovery for CURRENT goal:', currentGoal);
      
      // Analyze stuck position vs goal position
      if (this.robotPose) {
        const dx = currentGoal.x - this.robotPose.x;
        const dy = currentGoal.y - this.robotPose.y;
        
        console.log(`📊 Stuck Analysis:`);
        console.log(`- Robot: (${this.robotPose.x.toFixed(3)}, ${this.robotPose.y.toFixed(3)})`);
        console.log(`- Goal: (${currentGoal.x.toFixed(3)}, ${currentGoal.y.toFixed(3)})`);
        console.log(`- Delta: (${dx.toFixed(3)}, ${dy.toFixed(3)})`);
        console.log(`- Distance: ${Math.sqrt(dx*dx + dy*dy).toFixed(3)}m`);
      }
      
      // 1. Cancel current goal
      this.cancelCurrentGoal();
      await new Promise(res => setTimeout(res, 2000));
      
      // 2. Check if we're close enough to current goal
      const isCloseEnough = this.checkIfCloseToCurrentGoal();
      
      if (isCloseEnough) {
        console.log('🤖 Close enough to goal despite stuck, proceeding...');
        this.missionStatus = 'Close enough, proceeding...';
        this.navigationStatus.lastGoalCompleted = true;
        this.navigationStatus.status = 'Goal Completed';
        this.isWaitingForCompletion = false;
        this.stuckCounter = 0;
        
        if (resolve) {
          resolve(true);
        }
        
        if (this.missionActive) {
          setTimeout(() => {
            this.goToNextGoal();
          }, 1000);
        }
        return;
      }
      
      // 3. If not close, try to send goal again - ✅ FIX: Gunakan current goal yang benar
      console.log('🔄 Retrying CURRENT goal...');
      this.missionStatus = 'Retrying current goal...';
      await new Promise(res => setTimeout(res, 3000));
      
      // ✅ FIX: Retry CURRENT goal, bukan goal lama
      this.sendSingleGoal(currentGoal);
      
      // Give it some time to work
      await new Promise(res => setTimeout(res, 10000));
      
      // Check position again
      const isCloseAfterRetry = this.checkIfCloseToCurrentGoal();
      
      if (isCloseAfterRetry) {
        console.log('✅ Recovery successful, proceeding...');
        this.missionStatus = 'Recovery successful!';
        this.navigationStatus.lastGoalCompleted = true;
        this.navigationStatus.status = 'Goal Completed';
        this.isWaitingForCompletion = false;
        this.stuckCounter = 0;
        
        if (resolve) {
          resolve(true);
        }
        
        if (this.missionActive) {
          setTimeout(() => {
            this.goToNextGoal();
          }, 1000);
        }
      } else {
        console.log('❌ Recovery failed, skipping to next goal...');
        this.missionStatus = 'Recovery failed, skipping goal...';
        this.updateStatus('⚠️ Goal skipped due to stuck condition', 'error');
        
        // Skip to next goal
        this.isWaitingForCompletion = false;
        this.stuckCounter = 0;
        
        if (resolve) {
          resolve(false);
        }
        
        if (this.missionActive) {
          setTimeout(() => {
            this.goToNextGoal();
          }, 2000);
        }
      }
    },

    cancelCurrentGoal() {
      console.log('⏹️ Cancelling current goal...');
      
      if (this.cancelTopic) {
        const cancelMessage = new ROSLIB.Message({
          goal_info: {
            goal_id: {
              stamp: {
                sec: Math.floor(Date.now() / 1000),
                nanosec: 0
              },
              id: ''
            }
          }
        });
        this.cancelTopic.publish(cancelMessage);
      }
    },

    checkIfCloseToCurrentGoal() {
      if (!this.robotPose || !this.goals[this.currentMissionGoal]) return false;

      const currentGoal = this.goals[this.currentMissionGoal];
      const distanceToGoal = Math.sqrt(
        Math.pow(this.robotPose.x - currentGoal.x, 2) +
        Math.pow(this.robotPose.y - currentGoal.y, 2)
      );

      console.log(`📏 Distance to goal during recovery: ${distanceToGoal.toFixed(3)}m`);
      
      return distanceToGoal < 0.25; // 25cm threshold untuk recovery
    },

    checkPositionAndProceed(resolve, isTimeout = false) {
      if (!this.robotPose || !this.goals[this.currentMissionGoal] || !this.isWaitingForCompletion) return;

      const currentGoal = this.goals[this.currentMissionGoal];
      const distanceToGoal = Math.sqrt(
        Math.pow(this.robotPose.x - currentGoal.x, 2) +
        Math.pow(this.robotPose.y - currentGoal.y, 2)
      );

      console.log(`📏 Distance to goal: ${distanceToGoal.toFixed(3)}m`);

      // Adjust threshold berdasarkan kondisi
      const threshold = isTimeout ? 0.20 : 0.10; // ✅ DIKETATKAN: dari 0.25/0.15
      
      if (distanceToGoal < threshold) {
        console.log(`🎯 Close enough to goal (${isTimeout ? 'timeout' : 'normal'}), considering completed`);
        this.navigationStatus.lastGoalCompleted = true;
        this.navigationStatus.status = 'Goal Completed';
        this.navigationStatus.isActive = false;
        this.isWaitingForCompletion = false;
        this.stuckCounter = 0;
        
        if (resolve) {
          resolve(true);
        }
        
        // Jika mission aktif, lanjut ke goal berikutnya
        if (this.missionActive) {
          setTimeout(() => {
            this.goToNextGoal();
          }, 1000);
        }
      }
    },

    sendSingleGoal(goal) {
      if (!this.isConnected || !goal) {
        this.updateStatus('❌ Cannot send goal - not connected', 'error');
        return;
      }

      console.log('🎯 Sending single goal:', goal);

      const goalMessage = new ROSLIB.Message({
        header: {
          stamp: {
            sec: Math.floor(Date.now() / 1000),
            nanosec: 0
          },
          frame_id: 'map'
        },
        pose: {
          position: {
            x: goal.x,
            y: goal.y,
            z: 0.0
          },
          orientation: {
            x: 0.0,
            y: 0.0,
            z: goal.z || 0.0,
            w: goal.w || 1.0
          }
        }
      });

      try {
        this.goalTopic.publish(goalMessage);
        console.log('📤 Goal sent to /goal_pose');
        this.updateStatus('🚀 Goal sent to navigation system', 'connected');
      } catch (error) {
        console.error('Error sending goal:', error);
        this.navigationStatus.status = 'Error';
        this.navigationStatus.error = error.message;
        this.updateStatus('❌ Failed to send goal', 'error');
      }
    },

    sendCurrentGoal() {
      if (!this.isConnected || this.goals.length === 0) return;
      
      const goal = this.goals[this.currentMissionGoal];
      this.sendSingleGoal(goal);
    },

    manualRecovery() {
      if (!this.missionActive) return;
      
      console.log('🔄 Manual recovery triggered');
      this.missionStatus = 'Manual recovery...';
      this.handleStuckRecovery(null);
    },

    goToNextGoal() {
      console.log(`🔄 BEFORE goToNextGoal: currentMissionGoal = ${this.currentMissionGoal}, total goals = ${this.goals.length}`);
      
      this.currentMissionGoal++;
      console.log(`🔄 AFTER goToNextGoal: currentMissionGoal = ${this.currentMissionGoal}, total goals = ${this.goals.length}`);
      
      if (this.currentMissionGoal < this.goals.length) {
        const nextGoal = this.goals[this.currentMissionGoal];
        console.log(`🎯 Next goal details:`, nextGoal);
        console.log(`🔄 Moving to next goal: ${this.currentMissionGoal + 1}/${this.goals.length}`);
        this.missionStatus = `Moving to goal ${this.currentMissionGoal + 1}...`;
        
        // Tunggu sebentar sebelum goal berikutnya
        setTimeout(() => {
          this.executeCurrentGoalSequentially();
        }, 2000);
      } else {
        // Mission completed
        this.missionActive = false;
        const totalTime = ((Date.now() - this.missionStartTime) / 1000).toFixed(1);
        console.log(`🎉 MISSION COMPLETED SUCCESSFULLY!`);
        console.log(`📈 Summary: ${this.goals.length} goals completed in ${totalTime}s`);
        
        this.currentMissionGoal = 0;
        this.missionStatus = 'Mission Completed';
        this.navigationStatus.status = 'Mission Completed';
        this.navigationStatus.isActive = false;
        this.navigationStatus.feedback = `All ${this.goals.length} goals completed in ${totalTime}s`;
        this.updateStatus(`🎉 Mission completed! ${this.goals.length} goals reached in ${totalTime}s!`, 'connected');
      }
    },

    cancelMission() {
      console.log('⏹️ Cancelling mission');
      
      // Send cancel command
      this.cancelCurrentGoal();

      this.missionActive = false;
      this.isWaitingForCompletion = false;
      this.stuckCounter = 0;
      this.missionStatus = 'Mission Cancelled';
      this.navigationStatus.status = 'Mission Cancelled';
      this.navigationStatus.feedback = 'Mission cancelled by user';
      this.updateStatus('⏹️ Mission cancelled', 'connected');
    },

    // Method untuk manual goal activation check:
    checkGoalActivationManually() {
      console.log('🔍 Manual status check:');
      console.log('- Mission Active:', this.missionActive);
      console.log('- Current Goal:', this.currentMissionGoal + 1);
      console.log('- Total Goals:', this.goals.length);
      console.log('- Waiting for Completion:', this.isWaitingForCompletion);
      console.log('- Stuck Counter:', this.stuckCounter);
      console.log('- Navigation Status:', this.navigationStatus);
      console.log('- Robot Pose:', this.robotPose);
      console.log('- Y Offset:', this.yOffset);
      
      if (this.robotPose && this.goals[this.currentMissionGoal]) {
        const currentGoal = this.goals[this.currentMissionGoal];
        const distanceToGoal = Math.sqrt(
          Math.pow(this.robotPose.x - currentGoal.x, 2) +
          Math.pow(this.robotPose.y - currentGoal.y, 2)
        );
        console.log('- Distance to current goal:', distanceToGoal.toFixed(3), 'meters');
        
        // Juga tampilkan konversi pixel
        const robotPixels = this.calculatePixelCoordinates(this.robotPose.x, this.robotPose.y);
        const goalPixels = this.calculatePixelCoordinates(currentGoal.x, currentGoal.y);
        console.log('- Robot Pixel:', `(${robotPixels.px}, ${robotPixels.py})`);
        console.log('- Goal Pixel:', `(${goalPixels.px}, ${goalPixels.py})`);
      }
      
      this.updateStatus('🔍 Debug: Check console for details', 'connected');
    },

    getMissionStatusClass() {
      if (this.missionStatus.includes('stuck') || this.missionStatus.includes('failed')) {
        return 'mission-status-error';
      } else if (this.missionStatus.includes('recovery') || this.missionStatus.includes('Retrying')) {
        return 'mission-status-recovery';
      } else if (this.missionStatus.includes('Waiting') || this.missionStatus.includes('Moving')) {
        return 'mission-status-warning';
      } else if (this.missionStatus.includes('Completed')) {
        return 'mission-status-success';
      } else {
        return 'mission-status-normal';
      }
    },

    renderMapToCanvas(mapData) {
      const canvas = this.$refs.mapCanvas;
      if (!canvas) return;

      const ctx = canvas.getContext('2d');
      const width = mapData.info.width;
      const height = mapData.info.height;
      const data = mapData.data;

      ctx.clearRect(0, 0, width, height);

      const imageData = ctx.createImageData(width, height);

      for (let i = 0; i < data.length; i++) {
        const pixelIndex = i * 4;
        const cellValue = data[i];
        let r, g, b;

        if (cellValue === -1) {
          r = g = b = 128;
        } else if (cellValue === 0) {
          r = g = b = 255;
        } else if (cellValue === 100) {
          r = g = b = 0;
        } else {
          r = 255; g = 200; b = 0;
        }

        imageData.data[pixelIndex] = r;
        imageData.data[pixelIndex + 1] = g;
        imageData.data[pixelIndex + 2] = b;
        imageData.data[pixelIndex + 3] = 255;
      }

      ctx.putImageData(imageData, 0, 0);
    },

    getRobotIndicatorStyle() {
      if (!this.robotPose || !this.mapData) return {};
      
      const pixelCoords = this.calculatePixelCoordinates(this.robotPose.x, this.robotPose.y);
      const scale = 2;
      
      return {
        left: (pixelCoords.px * scale - 10) + 'px',
        top: (pixelCoords.py * scale - 15) + 'px',
        transform: `rotate(${this.robotPose.thetaDeg}deg)`
      };
    },

    getGoalIndicatorStyle(goal) {
      const pixelCoords = this.calculatePixelCoordinates(goal.x, goal.y);
      const scale = 2;
      
      return {
        left: (pixelCoords.px * scale - 15) + 'px',
        top: (pixelCoords.py * scale - 15) + 'px'
      };
    },

    getStatusClass(status) {
      const statusClasses = {
        'Idle': 'status-idle',
        'Goal Sent': 'status-active',
        'Navigating to Goal': 'status-active',
        'Mission Started': 'status-active',
        'Goal Completed': 'status-success',
        'Mission Completed': 'status-success',
        'Goal Cancelled': 'status-error',
        'Mission Cancelled': 'status-error',
        'Goal Failed': 'status-error',
        'Timeout': 'status-error',
        'Error': 'status-error'
      };
      return statusClasses[status] || 'status-idle';
    },

    quaternionToYaw(quat) {
      const x = quat.x;
      const y = quat.y;
      const z = quat.z;
      const w = quat.w;
      const siny_cosp = 2 * (w * z + x * y);
      const cosy_cosp = 1 - 2 * (y * y + z * z);
      return Math.atan2(siny_cosp, cosy_cosp);
    },

    updateStatus(message, statusClass) {
      this.connectionStatus = {
        message,
        class: statusClass
      };
    }
  },
  mounted() {
    if (this.mapData) {
      this.renderMapToCanvas(this.mapData);
    }
  }
};
</script>

<style scoped>
/* Previous styles remain the same, dengan beberapa tambahan */
.goal-item.completed {
  background-color: #d4edda;
  border-color: #c3e6cb;
}

.goal-item.active {
  background-color: #fff3cd;
  border-color: #ffeaa7;
}

.goal-status.active {
  color: #28a745;
  font-weight: bold;
}

.goal-status.completed {
  color: #6c757d;
}

.mission-status {
  font-weight: bold;
  margin-top: 10px;
  padding: 5px;
  border-radius: 3px;
}

/* Previous styles continue... */
.nav2-map-controller {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
  font-family: Arial, sans-serif;
}

.status {
  padding: 10px;
  border-radius: 5px;
  margin: 10px 0;
  font-weight: bold;
}

.status.connected { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
.status.error { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
.status.disconnected { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }

.main-layout {
  display: grid;
  grid-template-columns: 1fr 400px;
  gap: 20px;
  margin-top: 20px;
}

.map-section {
  background-color: #f8f9fa;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.map-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 15px;
}

.map-header h3 {
  margin: 0;
  color: #2c3e50;
}

.map-controls {
  display: flex;
  gap: 10px;
}

.mode-btn {
  padding: 8px 12px;
  border: 2px solid #007bff;
  background-color: white;
  color: #007bff;
  border-radius: 5px;
  cursor: pointer;
  font-size: 12px;
}

.mode-btn.active {
  background-color: #007bff;
  color: white;
}

.clear-btn {
  padding: 8px 12px;
  background-color: #dc3545;
  color: white;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-size: 12px;
}

.map-container {
  position: relative;
  display: inline-block;
  margin-bottom: 15px;
}

.map-container canvas {
  border: 2px solid #333;
  background-color: #666;
  image-rendering: pixelated;
  max-width: 100%;
  height: auto;
}

.robot-indicator {
  position: absolute;
  width: 20px;
  height: 20px;
  pointer-events: none;
  z-index: 10;
  transition: all 0.3s ease;
}

.robot-dot {
  width: 12px;
  height: 12px;
  background-color: #ff4444;
  border: 2px solid #cc0000;
  border-radius: 50%;
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
}

.robot-arrow {
  width: 0;
  height: 0;
  border-left: 5px solid transparent;
  border-right: 5px solid transparent;
  border-bottom: 8px solid #ff0000;
  position: absolute;
  top: -6px;
  left: 50%;
  transform: translateX(-50%);
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
  background-color: #28a745;
  border: 3px solid #1e7e34;
  border-radius: 50%;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: bold;
  font-size: 12px;
  transition: transform 0.2s;
}

.goal-indicator:hover .goal-marker {
  transform: scale(1.2);
  background-color: #20c997;
}

.map-info {
  background-color: white;
  padding: 10px;
  border-radius: 5px;
  border: 1px solid #dee2e6;
  font-size: 14px;
}

.control-section {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.info-panel, .robot-panel, .goals-panel, .mission-panel, .status-panel, .connection-panel {
  background-color: #f8f9fa;
  padding: 15px;
  border-radius: 8px;
  border: 1px solid #dee2e6;
}

.info-panel h3, .robot-panel h3, .goals-panel h3, .mission-panel h3, .status-panel h3, .connection-panel h3 {
  margin-top: 0;
  color: #2c3e50;
  font-size: 16px;
}

.robot-panel button {
  width: 100%;
  margin-top: 10px;
}

.add-btn {
  background-color: #28a745;
  color: white;
  border: none;
  padding: 8px 12px;
  border-radius: 4px;
  cursor: pointer;
}

.goals-list {
  max-height: 200px;
  overflow-y: auto;
}

.goal-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px;
  margin: 5px 0;
  background-color: white;
  border-radius: 4px;
  border: 1px solid #dee2e6;
}

.goal-info {
  display: flex;
  gap: 10px;
  align-items: center;
}

.goal-number {
  font-weight: bold;
  color: #28a745;
}

.goal-coords {
  font-family: monospace;
  font-size: 12px;
}

.goal-actions {
  display: flex;
  gap: 5px;
}

.send-btn, .remove-btn {
  padding: 4px 8px;
  border: none;
  border-radius: 3px;
  cursor: pointer;
  font-size: 12px;
}

.send-btn {
  background-color: #007bff;
  color: white;
}

.remove-btn {
  background-color: #dc3545;
  color: white;
}

.no-goals {
  text-align: center;
  color: #6c757d;
  font-style: italic;
  padding: 20px;
}

.mission-buttons {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.mission-btn {
  padding: 10px;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-weight: bold;
}

.mission-btn.primary {
  background-color: #ffc107;
  color: #212529;
}

.mission-btn:not(.primary) {
  background-color: #17a2b8;
  color: white;
}

.mission-btn.debug-btn {
  background-color: #6f42c1;
  color: white;
}

.cancel-btn {
  background-color: #dc3545;
  color: white;
  padding: 10px;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  font-weight: bold;
}

.status-info {
  background-color: white;
  padding: 10px;
  border-radius: 5px;
  border: 1px solid #dee2e6;
  font-size: 14px;
}

.status-idle { color: #6c757d; }
.status-active { color: #007bff; font-weight: bold; }
.status-success { color: #28a745; font-weight: bold; }
.status-error { color: #dc3545; font-weight: bold; }

.error-text {
  color: #dc3545;
  font-weight: bold;
}

.connection-controls {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
}

.connection-controls button {
  flex: 1;
  padding: 8px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  background-color: #007bff;
  color: white;
}

.connection-settings label {
  display: flex;
  flex-direction: column;
  font-weight: bold;
  font-size: 14px;
}

.connection-settings input {
  padding: 6px;
  border: 1px solid #ced4da;
  border-radius: 4px;
  margin-top: 5px;
}

button:disabled {
  background-color: #6c757d !important;
  cursor: not-allowed;
  opacity: 0.6;
}

button:not(:disabled):hover {
  opacity: 0.9;
}
</style>