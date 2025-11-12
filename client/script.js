// Инициализация WebSocket и переменных
const WS_URL = "ws://localhost:8080/stream";
let ws = null;
let connectionId = null;
let roomId = null; // Глобальная переменная для хранения ID комнаты
let roomName = null; // Глобальная переменная для хранения названия комнаты

// === DOM Элементы ===

// Элементы для экрана входа
const landingEl = document.getElementById("landing");
const appEl = document.getElementById("app");
const usernameInput = document.getElementById("username");
const roomNameInput = document.getElementById("roomName");
const roomIdInput = document.getElementById("roomId");
const submitBtn = document.getElementById("submitBtn");
const joinFields = document.getElementById("joinFields");
const createFields = document.getElementById("createFields");
const modeButtons = document.querySelectorAll(".mode-btn");

// Элементы для комнаты
const chatBox = document.getElementById("chatBox");
const chatInput = document.getElementById("chatInput");
const sendChatBtn = document.getElementById("sendChatBtn");
const videoEl = document.getElementById("video");
const userListEl = document.getElementById("userList");
const roomTitleEl = document.getElementById("roomTitle");

// === УТИЛИТЫ ===

// Генерация уникального идентификатора
function genConnectionId() {
    if (crypto && typeof crypto.randomUUID === "function") return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// Логирование сообщений
function log(...args) {
    console.log(...args);
}

// Обновление списка участников
function updateUserList(usernames) {
    userListEl.innerHTML = "";
    usernames.forEach(name => {
        const li = document.createElement("div");
        li.classList.add("participant");
        // Берем первую букву имени для аватара и переводим в верхний регистр
        const avatarLetter = name[0] ? name[0].toUpperCase() : '?';
        li.innerHTML = `<div class="avatar">${avatarLetter}</div><div class="participant-info"><div class="participant-name">${name}</div><div class="participant-status">Смотрит</div></div>`;
        userListEl.appendChild(li);
    });
}

/**
 * Добавляет сообщение в чат.
 * @param {object} message - Объект сообщения.
 * @param {boolean} isOwn - true, если сообщение отправлено текущим пользователем.
 */
function addChatMessage(message, isOwn) {
    const div = document.createElement("div");
    // isOwn = true - наше сообщение ('own'), иначе - чужое ('other')
    div.classList.add("message");
    div.classList.add(isOwn ? "own" : "other");

    // Используем 'Я' для своего сообщения в заголовке
    const authorName = isOwn ? 'Я' : message.username;

    div.innerHTML = `<div class="message-author">${authorName}</div>${message.text}`;

    chatBox.appendChild(div);
    chatBox.scrollTop = chatBox.scrollHeight;
}

/**
 * Переключает видимость между экраном входа и экраном комнаты и инициирует подключение.
 * @param {string} username - Имя пользователя.
 * @param {string} room - ID комнаты.
 * @param {string} name - Название комнаты.
 */
function enterRoom(username, room, name) {
    if (username && room) {
        // 1. Прячем экран входа и показываем экран комнаты
        landingEl.classList.add("hidden");
        appEl.classList.remove("hidden");

        // 2. Устанавливаем глобальные переменные и обновляем UI
        roomId = room;
        roomName = name || "Untitled Room"; // Используем переданное название или дефолтное
        if (roomTitleEl) {
            roomTitleEl.textContent = `🎬 ${roomName}`;
        }

        // 3. Подключаемся к WebSocket
        connect(username);
    } else {
        alert("Необходимо ввести имя пользователя и ID комнаты.");
    }
}


// === ФУНКЦИЯ ПОДКЛЮЧЕНИЯ К WS ===

function connect(username) {
    if (!roomId) {
        log("Ошибка: ID комнаты не задан перед подключением.");
        return;
    }

    connectionId = genConnectionId();
    ws = new WebSocket(WS_URL);

    ws.addEventListener("open", () => {
        log("[WS] connected to room:", roomId);
        const userInit = {
            type: 'init',
            ConnectionId: connectionId,
            Username: username,
            RoomId: roomId
        };
        ws.send(JSON.stringify(userInit));
        log("[WS] sent init:", userInit);
    });

    ws.addEventListener("message", (ev) => {
        const message = JSON.parse(ev.data);
        // Предполагаем, что сервер может добавить ConnectionId к исходящим сообщениям
        const isOwn = message.ConnectionId === connectionId;

        // Обработка обновлений пользователей
        if (message && message.type === 'user_list_update') {
            updateUserList(message.payload.usernames);
            return;
        }

        // Обработка сообщений чата
        if (message && message.type === 'chat_message') {
            addChatMessage(message, isOwn);
            return;
        }

        // Обработка команд плеера (воспроизведение, пауза, перемотка)
        if (message && message.type === 'video_action') {
            // Игнорируем собственное сообщение, чтобы избежать конфликтов и зацикливания
            if (isOwn) return;

            const action = message.action;

            if (action === 'play') {
                videoEl.play().catch(err => log("Ошибка воспроизведения:", err));
            } else if (action === 'pause') {
                videoEl.pause();
            } else if (action === 'seek' && typeof message.time === 'number') {
                // Устанавливаем время воспроизведения, если пришло сообщение о перемотке
                videoEl.currentTime = message.time;
            }
            log(`[WS] Received video action: ${action}`);
            return;
        }

        log("[WS] Unknown message type or missing type:", message);
    });

    ws.addEventListener("close", () => {
        log("[WS] disconnected");
    });

    ws.addEventListener("error", (err) => {
        log("[WS] error", err);
    });
}


// === ОБРАБОТЧИКИ СОБЫТИЙ ДЛЯ ЭКРАНА ВХОДА ===

let currentMode = "join"; // Текущий режим: "join" или "create"

// Функция переключения режима
function switchMode(mode) {
    currentMode = mode;

    // Обновляем активную кнопку переключателя
    modeButtons.forEach(btn => {
        if (btn.dataset.mode === mode) {
            btn.classList.add("active");
        } else {
            btn.classList.remove("active");
        }
    });

    // Показываем/скрываем соответствующие поля
    if (mode === "join") {
        if (joinFields) joinFields.classList.remove("hidden");
        if (createFields) createFields.classList.add("hidden");
        if (submitBtn) submitBtn.textContent = "Join Room";
    } else {
        if (joinFields) joinFields.classList.add("hidden");
        if (createFields) createFields.classList.remove("hidden");
        if (submitBtn) submitBtn.textContent = "Create Room";
    }
}

// Обработчики для переключателя режимов
modeButtons.forEach(btn => {
    btn.addEventListener("click", () => {
        switchMode(btn.dataset.mode);
    });
});

// Обработчик для кнопки отправки
submitBtn.addEventListener("click", () => {
    const username = usernameInput.value.trim();

    if (!username) {
        alert("Введите ваше имя.");
        return;
    }

    if (currentMode === "join") {
        // Режим присоединения
        const room = roomIdInput.value.trim();
        if (!room) {
            alert("Введите ID комнаты.");
            return;
        }
        enterRoom(username, room, "");
    } else {
        // Режим создания
        const roomName = roomNameInput.value.trim();
        if (!roomName) {
            alert("Введите название комнаты.");
            return;
        }
        const room = genConnectionId(); // Генерируем новый уникальный ID комнаты
        enterRoom(username, room, roomName);
    }
});


// === ОБРАБОТЧИКИ СОБЫТИЙ ДЛЯ КОМНАТЫ (ЧАТ) ===

// Отправка сообщения в чат
sendChatBtn.addEventListener("click", () => {
    const message = chatInput.value.trim();
    if (message && ws && ws.readyState === WebSocket.OPEN) {
        const chatMessage = {
            type: 'chat_message',
            text: message
            // username, ConnectionId и RoomId будут добавлены на сервере
        };
        ws.send(JSON.stringify(chatMessage));

        // Очищаем поле ввода. (Сервер должен отразить сообщение обратно всем, включая нас, 
        // где оно будет добавлено в чат функцией addChatMessage с флагом isOwn=true).
        chatInput.value = '';
    }
});

// Отправка сообщения по нажатию Enter
chatInput.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
        e.preventDefault(); // Предотвращаем стандартное действие (перенос строки)
        sendChatBtn.click();
    }
});


// === ОБРАБОТЧИКИ СОБЫТИЙ ДЛЯ КОМНАТЫ (ПЛЕЕР) ===

// Отправляет команду действия с видео на сервер
function sendVideoAction(action, time) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        const message = {
            type: 'video_action',
            action: action
        };
        if (typeof time === 'number') {
            message.time = time;
        }
        ws.send(JSON.stringify(message));
    }
}

// Обработка клика на само видео для переключения play/pause (как на YouTube)
videoEl.addEventListener('click', (e) => {
    // Проверяем, что клик был именно на видео, а не на контролах
    // Контролы обычно находятся в нижней части видео
    const rect = videoEl.getBoundingClientRect();
    const clickY = e.clientY - rect.top;
    const videoHeight = rect.height;

    // Если клик в области контролов (нижние 15% видео), не обрабатываем
    // Иначе переключаем play/pause
    if (clickY < videoHeight * 0.85) {
        e.preventDefault();
        e.stopPropagation();
        if (videoEl.paused) {
            videoEl.play().catch(err => log("Ошибка воспроизведения:", err));
        } else {
            videoEl.pause();
        }
    }
});

// Событие: Видео начало воспроизведение
videoEl.addEventListener('play', () => {
    // Отправка сигнала "play" от элементов управления видео
    sendVideoAction('play');
});

// Событие: Видео поставлено на паузу
videoEl.addEventListener('pause', () => {
    // Отправка сигнала "pause" от элементов управления видео
    sendVideoAction('pause');
});

// Событие: Перемотка (пользователь изменил currentTime)
videoEl.addEventListener('seeked', () => {
    // Отправка сигнала "seek" с текущим временем
    sendVideoAction('seek', videoEl.currentTime);
});

// Инициализация: убеждаемся, что по умолчанию активен режим "Join Room"
document.addEventListener('DOMContentLoaded', () => {
    switchMode("join");
});