let videoPlayer = null;
let isSyncing = false; // Flag to prevent infinite loops when applying remote commands

function findVideoPlayer() {
    // Attempt to find common video player elements
    videoPlayer = document.querySelector('video');

    if (!videoPlayer) {
        // Specific selectors for popular sites if generic fails
        if (window.location.hostname.includes('youtube.com')) {
            videoPlayer = document.querySelector('.html5-main-video');
        } else if (window.location.hostname.includes('netflix.com')) {
            videoPlayer = document.querySelector('.player-video');
        }
        // Add more specific selectors for other sites as needed
    }

    if (videoPlayer) {
        console.log('Video player found:', videoPlayer);
        attachEventListeners(videoPlayer);
    } else {
        console.log('No video player found on this page.');
    }
}

function attachEventListeners(player) {
    player.addEventListener('play', () => sendPlayerState('play'));
    player.addEventListener('pause', () => sendPlayerState('pause'));
    player.addEventListener('seeked', () => sendPlayerState('seek')); // 'seeked' fires after seeking is complete
    player.addEventListener('ratechange', () => sendPlayerState('ratechange')); // For playback speed changes
}

function sendPlayerState(eventType) {
    if (isSyncing) return; // Don't send events if we're currently applying a remote sync

    if (videoPlayer) {
        const state = {
            eventType: eventType,
            paused: videoPlayer.paused,
            currentTime: videoPlayer.currentTime,
            playbackRate: videoPlayer.playbackRate
        };
        console.log('Sending player state:', state);
        chrome.runtime.sendMessage({ type: 'PLAYER_STATE_CHANGE', state });
    }
}

// Function to apply remote player commands
function applyPlayerCommand(command) {
    if (!videoPlayer) {
        console.warn('No video player to apply command to.');
        return;
    }

    isSyncing = true; // Set flag to prevent sending events back to background script

    switch (command.eventType) {
        case 'play':
            if (videoPlayer.paused) {
                videoPlayer.play().catch(e => console.error('Error playing video:', e));
            }
            break;
        case 'pause':
            if (!videoPlayer.paused) {
                videoPlayer.pause();
            }
            break;
        case 'seek':
            // Only seek if the difference is significant to avoid excessive seeking
            if (Math.abs(videoPlayer.currentTime - command.currentTime) > 1) {
                videoPlayer.currentTime = command.currentTime;
            }
            break;
        case 'ratechange':
            if (videoPlayer.playbackRate !== command.playbackRate) {
                videoPlayer.playbackRate = command.playbackRate;
            }
            break;
        default:
            console.warn('Unknown player command:', command.eventType);
    }

    // Reset flag after a short delay to allow player to settle
    setTimeout(() => {
        isSyncing = false;
    }, 100);
}

// Listen for messages from the background script
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'APPLY_PLAYER_COMMAND') {
        console.log('Applying remote player command:', message.command);
        applyPlayerCommand(message.command);
    }
});

// Initial setup
findVideoPlayer();

// Observe for dynamically added video players (e.g., single-page applications)
const observer = new MutationObserver(() => {
    if (!videoPlayer) {
        findVideoPlayer();
    }
});
observer.observe(document.body, { childList: true, subtree: true });