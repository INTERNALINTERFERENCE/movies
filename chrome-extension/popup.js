document.addEventListener('DOMContentLoaded', () => {
    const usernameInput = document.getElementById('username');
    const roomIdInput = document.getElementById('roomId');
    const connectBtn = document.getElementById('connect-btn');
    const disconnectBtn = document.getElementById('disconnect-btn');
    const connectionStatusIndicator = document.getElementById('status-indicator');
    const connectionStatusText = document.getElementById('status-text');
    const mainControls = document.getElementById('main-controls');
    const roomInfo = document.getElementById('room-info');
    const connectedRoomId = document.getElementById('connected-room-id');
    const userList = document.getElementById('user-list');
    const remoteAudioContainer = document.getElementById('remote-audio-container');

    const remoteAudioElements = new Map(); // Map<remoteConnectionId, HTMLAudioElement>

    // Load saved username and room ID
    chrome.storage.sync.get(['username', 'roomId'], (data) => {
        if (data.username) {
            usernameInput.value = data.username;
        }
        if (data.roomId) {
            roomIdInput.value = data.roomId;
        }
    });

    function updateUI(isConnected, currentRoomId = '', users = []) {
        if (isConnected) {
            mainControls.classList.add('hidden');
            roomInfo.classList.remove('hidden');
            connectionStatusIndicator.classList.remove('disconnected', 'connecting');
            connectionStatusIndicator.classList.add('connected');
            connectionStatusText.textContent = 'Connected';
            connectedRoomId.textContent = currentRoomId;

            userList.innerHTML = '';
            if (users.length > 0) {
                users.forEach(user => {
                    const li = document.createElement('li');
                    li.textContent = user;
                    userList.appendChild(li);
                });
            } else {
                const li = document.createElement('li');
                li.textContent = 'No other users in room.';
                userList.appendChild(li);
            }
        } else {
            mainControls.classList.remove('hidden');
            roomInfo.classList.add('hidden');
            connectionStatusIndicator.classList.remove('connected', 'connecting');
            connectionStatusIndicator.classList.add('disconnected');
            connectionStatusText.textContent = 'Disconnected';
            userList.innerHTML = ''; // Clear user list on disconnect
            // Clear all remote audio elements on disconnect
            remoteAudioElements.forEach(audioEl => audioEl.remove());
            remoteAudioElements.clear();
            remoteAudioContainer.classList.add('hidden');
        }
    }

    // Initial UI update based on current connection state (if known)
    chrome.runtime.sendMessage({ type: 'GET_CONNECTION_STATE' }, (response) => {
        if (response && response.isConnected) {
            updateUI(true, response.roomId, response.users);
        } else {
            updateUI(false);
        }
    });

    connectBtn.addEventListener('click', () => {
        const username = usernameInput.value.trim();
        const roomId = roomIdInput.value.trim();

        if (!username || !roomId) {
            alert('Please enter both username and room ID.');
            return;
        }

        chrome.storage.sync.set({ username, roomId }, () => {
            console.log('Username and Room ID saved.');
        });

        connectionStatusIndicator.classList.remove('disconnected', 'connected');
        connectionStatusIndicator.classList.add('connecting');
        connectionStatusText.textContent = 'Connecting...';

        chrome.runtime.sendMessage({ type: 'CONNECT', username, roomId });
    });

    disconnectBtn.addEventListener('click', () => {
        chrome.runtime.sendMessage({ type: 'DISCONNECT' });
        // updateUI(false) will be called by background script's CONNECTION_STATUS message
    });

    // Listen for messages from the background script
    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.type === 'CONNECTION_STATUS') {
            updateUI(message.isConnected, message.roomId, message.users);
        } else if (message.type === 'REMOTE_AUDIO_STREAM') {
            console.log('Received remote audio stream for:', message.remoteConnectionId);
            const audioEl = new Audio();
            audioEl.autoplay = true;
            audioEl.controls = true; // For debugging, can be removed later
            audioEl.srcObject = message.stream;
            audioEl.id = `audio-${message.remoteConnectionId}`;
            remoteAudioContainer.appendChild(audioEl);
            remoteAudioElements.set(message.remoteConnectionId, audioEl);
            remoteAudioContainer.classList.remove('hidden');
        } else if (message.type === 'REMOTE_AUDIO_STREAM_CLOSED') {
            console.log('Remote audio stream closed for:', message.remoteConnectionId);
            const audioEl = remoteAudioElements.get(message.remoteConnectionId);
            if (audioEl) {
                audioEl.remove();
                remoteAudioElements.delete(message.remoteConnectionId);
                if (remoteAudioElements.size === 0) {
                    remoteAudioContainer.classList.add('hidden');
                }
            }
        }
    });
});