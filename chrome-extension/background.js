let ws = null;
let isConnected = false;
let currentRoomId = '';
let currentUser = null; // { username, roomId, connectionId }
let usersInRoom = []; // Stores usernames for popup display
let usersInRoomFull = []; // Stores full user objects for WebRTC peer management

// WebRTC specific state
const peerConnections = new Map(); // Map<connectionId, RTCPeerConnection>
let localStream = null; // User's local audio stream

const WS_URL = 'wss://bentlee-gloomful-unvividly.ngrok-free.dev/stream'; // TODO: Make this configurable
const ICE_SERVERS = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' }
    ]
};

function generateConnectionId() {
    return 'conn-' + Math.random().toString(36).substr(2, 9);
}

function sendConnectionStatusToPopup() {
    chrome.runtime.sendMessage({
        type: 'CONNECTION_STATUS',
        isConnected: isConnected,
        roomId: currentRoomId,
        users: usersInRoom // Send usernames for display
    });
}

// --- WebRTC Functions ---
async function startLocalStream() {
    if (localStream) return; // Already started

    try {
        localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        console.log('Local audio stream started.');
        // Add tracks to existing peer connections
        peerConnections.forEach(pc => {
            localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
        });
    } catch (e) {
        console.error('Error getting local audio stream:', e);
    }
}

function createPeerConnection(remoteConnectionId) {
    const pc = new RTCPeerConnection(ICE_SERVERS);
    peerConnections.set(remoteConnectionId, pc);

    // Add local stream tracks
    if (localStream) {
        localStream.getTracks().forEach(track => pc.addTrack(track, localStream));
    }

    pc.onicecandidate = (event) => {
        if (event.candidate) {
            sendWebRTCMessage(remoteConnectionId, 'webrtc-ice-candidate', event.candidate);
        }
    };

    pc.ontrack = (event) => {
        // This event fires when a remote stream is added
        console.log('Remote track received:', event.track, event.streams);
        // Forward this stream to the popup or a dedicated page to play
        chrome.runtime.sendMessage({
            type: 'REMOTE_AUDIO_STREAM',
            streamId: event.streams[0].id,
            remoteConnectionId: remoteConnectionId,
            stream: event.streams[0] // Pass the stream object
        });
    };

    pc.onconnectionstatechange = () => {
        console.log(`WebRTC connection to ${remoteConnectionId} state: ${pc.connectionState}`);
        if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed' || pc.connectionState === 'closed') {
            closeWebRTCConnection(remoteConnectionId);
        }
    };

    return pc;
}

async function startWebRTCConnection(remoteConnectionId, isInitiator) {
    console.log(`Starting WebRTC connection with ${remoteConnectionId}, initiator: ${isInitiator}`);
    const pc = createPeerConnection(remoteConnectionId);

    if (isInitiator) {
        pc.onnegotiationneeded = async () => {
            try {
                const offer = await pc.createOffer();
                await pc.setLocalDescription(offer);
                sendWebRTCMessage(remoteConnectionId, 'webrtc-offer', pc.localDescription);
            } catch (e) {
                console.error('Error creating or sending offer:', e);
            }
        };
    }
}

function closeWebRTCConnection(remoteConnectionId) {
    const pc = peerConnections.get(remoteConnectionId);
    if (pc) {
        console.log(`Closing WebRTC connection with ${remoteConnectionId}`);
        pc.close();
        peerConnections.delete(remoteConnectionId);
        // Notify popup to remove audio element
        chrome.runtime.sendMessage({
            type: 'REMOTE_AUDIO_STREAM_CLOSED',
            remoteConnectionId: remoteConnectionId
        });
    }
}

function sendWebRTCMessage(targetConnectionId, type, payload) {
    if (ws && ws.readyState === WebSocket.OPEN && currentUser) {
        const wsMessage = {
            Type: type,
            Payload: payload,
            Sender: currentUser.connectionId,
            Target: targetConnectionId,
            RoomId: currentUser.roomId
        };
        ws.send(JSON.stringify(wsMessage));
    }
}

// --- WebSocket Functions ---
function connectWebSocket(username, roomId) {
    if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) {
        console.log('WebSocket already connected or connecting.');
        return;
    }

    currentUser = {
        username: username,
        roomId: roomId,
        connectionId: generateConnectionId()
    };

    ws = new WebSocket(WS_URL);
    isConnected = false;
    currentRoomId = roomId;
    sendConnectionStatusToPopup(); // Update popup to 'connecting'

    ws.onopen = async () => {
        console.log('WebSocket connected.');
        isConnected = true;
        // Send initial user data to the backend
        ws.send(JSON.stringify(currentUser));
        sendConnectionStatusToPopup(); // Update popup to 'connected'

        await startLocalStream(); // Start local audio stream
    };

    ws.onmessage = async (event) => {
        console.log('WebSocket message received:', event.data);
        try {
            const message = JSON.parse(event.data);

            // Ignore messages sent by self
            if (currentUser && message.Sender === currentUser.connectionId) {
                console.log('Ignoring self-sent message.');
                return;
            }

            if (message.Type === 'user_list_update') {
                const oldUsersInRoomFull = new Map(usersInRoomFull.map(u => [u.connectionId, u]));
                usersInRoomFull = message.Payload.Users; // Now an array of full user objects
                usersInRoom = usersInRoomFull.map(u => u.username); // For popup display

                sendConnectionStatusToPopup(); // Update popup with new user list

                // Handle WebRTC connections for new/leaving users
                const currentPeerIds = new Set(peerConnections.keys());
                const newUsers = usersInRoomFull.filter(u =>
                    u.connectionId !== currentUser.connectionId && !oldUsersInRoomFull.has(u.connectionId)
                );
                const leavingPeerIds = Array.from(currentPeerIds).filter(id =>
                    !usersInRoomFull.some(u => u.connectionId === id)
                );

                newUsers.forEach(newUser => {
                    // Initiate offer for new users
                    startWebRTCConnection(newUser.connectionId, true);
                });

                leavingPeerIds.forEach(leavingId => {
                    closeWebRTCConnection(leavingId);
                });

            } else if (message.Type === 'player_sync') {
                // Forward player sync commands to the active content script
                chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
                    if (tabs[0]) {
                        chrome.tabs.sendMessage(tabs[0].id, {
                            type: 'APPLY_PLAYER_COMMAND',
                            command: message.Payload
                        });
                    }
                });
            } else if (message.Type === 'webrtc-offer') {
                const remoteConnectionId = message.Sender;
                let pc = peerConnections.get(remoteConnectionId);
                if (!pc) {
                    pc = createPeerConnection(remoteConnectionId);
                }

                await pc.setRemoteDescription(new RTCSessionDescription(message.Payload));
                const answer = await pc.createAnswer();
                await pc.setLocalDescription(answer);
                sendWebRTCMessage(remoteConnectionId, 'webrtc-answer', pc.localDescription);

            } else if (message.Type === 'webrtc-answer') {
                const remoteConnectionId = message.Sender;
                const pc = peerConnections.get(remoteConnectionId);
                if (pc) {
                    await pc.setRemoteDescription(new RTCSessionDescription(message.Payload));
                } else {
                    console.warn(`Received answer for unknown peer ${remoteConnectionId}`);
                }
            } else if (message.Type === 'webrtc-ice-candidate') {
                const remoteConnectionId = message.Sender;
                const pc = peerConnections.get(remoteConnectionId);
                if (pc) {
                    try {
                        await pc.addIceCandidate(new RTCIceCandidate(message.Payload));
                    } catch (e) {
                        console.error('Error adding received ICE candidate:', e);
                    }
                } else {
                    console.warn(`Received ICE candidate for unknown peer ${remoteConnectionId}`);
                }
            }
        } catch (e) {
            console.error('Failed to parse or process WebSocket message:', e);
        }
    };

    ws.onclose = () => {
        console.log('WebSocket disconnected.');
        isConnected = false;
        currentRoomId = '';
        currentUser = null;
        usersInRoom = [];
        usersInRoomFull = [];
        sendConnectionStatusToPopup(); // Update popup to 'disconnected'

        // Close all WebRTC connections
        peerConnections.forEach(pc => pc.close());
        peerConnections.clear();
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
            localStream = null;
        }
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        // onclose will be called after onerror, so no need to duplicate status update here
    };
}

function disconnectWebSocket() {
    if (ws) {
        ws.close();
    }
}

// Listen for messages from the popup script and content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'CONNECT') {
        connectWebSocket(message.username, message.roomId);
    } else if (message.type === 'DISCONNECT') {
        disconnectWebSocket();
    } else if (message.type === 'GET_CONNECTION_STATE') {
        sendResponse({
            isConnected: isConnected,
            roomId: currentRoomId,
            users: usersInRoom
        });
    } else if (message.type === 'PLAYER_STATE_CHANGE') {
        // Received player state change from content script, send to backend
        if (ws && ws.readyState === WebSocket.OPEN && currentUser) {
            const wsMessage = {
                Type: 'player_sync',
                Payload: message.state,
                Sender: currentUser.connectionId,
                RoomId: currentUser.roomId // Include RoomId for backend routing if needed
            };
            ws.send(JSON.stringify(wsMessage));
        }
    }
});