# Frontend Integration Guide: Rich Chat Features

This guide explains how the backend handles advanced chat features and how the frontend should implement them using REST APIs and WebSocket events.

---

## 1. Rich Messaging (Replies, Edits, Deletes)

### A. Message Replies
**Backend Design:** Messages have an optional `replyToId`. When fetching history, the backend populates a `replyTo` object (one level deep) containing the original message's content and sender info.

*   **Implementation (REST):** When sending a message (`POST /chat/rooms/:roomId/messages`), include `replyToId` in the JSON body.
*   **UI Rendering:** Check if `message.replyTo` is not null. If present, render the original message snippet above the new message.

### B. Message Editing
**Backend Design:** Senders can modify their own messages. The backend updates the text, sets `isEdited: true`, and broadcasts the change.

*   **Implementation (REST):** `PATCH /chat/messages/:messageId` with `{ "content": "new text" }`.
*   **Real-time (WS):** Listen for `type: "message_edited"`.
*   **Payload:** `{ "messageId": "...", "content": "..." }`.
*   **Action:** Update the message in the local state and display an "(edited)" label.

### C. Soft-Deletion (Redaction)
**Backend Design:** Messages are never hard-deleted to preserve history. The backend redacts the content and sets `isDeleted: true`.

*   **Implementation (REST):** `DELETE /chat/messages/:messageId`.
*   **Real-time (WS):** Listen for `type: "message_deleted"`.
*   **Payload:** `{ "messageId": "..." }`.
*   **Action:** Replace message content with *"This message was deleted"*, remove reactions, and hide edit buttons.

---

## 2. Interactive Reactions (Emoji Sync)

**Backend Design:** Reactions are stored as a map of `userId -> emoji`. The system supports "toggling"—sending the same emoji twice removes it.

*   **Implementation (REST):** `PUT /chat/messages/:messageId/reactions` with `{ "emoji": "👍" }`.
*   **Real-time (WS):** Listen for `type: "reaction_updated"`.
*   **Payload:** `{ "messageId": "...", "userId": "...", "emoji": "..." }`.
*   **Action:** 
    *   If `emoji` is an empty string `""`, remove that `userId` from the local message's reaction map.
    *   Otherwise, update `reactions[userId] = emoji`.
*   **UI Tip:** Aggregate reactions by emoji type to show counts (e.g., 👍 3, ❤️ 2).

---

## 3. Automatic Synchronization (Chat List)

**Backend Design:** The backend ensures that every message sent triggers a "heartbeat" for the room, signaling it should jump to the top of the chat list.

*   **Real-time (WS):** Listen for `type: "room_updated"`.
*   **Payload:**
    ```json
    {
      "roomId": "...",
      "payload": {
        "lastMessage": "Hello!",
        "lastUpdated": "2026-03-07T...",
        "lastSenderId": "..."
      }
    }
    ```
*   **Action:**
    1.  Find the room in your local list by `roomId`.
    2.  Update its `lastMessage` and `lastUpdated` timestamp.
    3.  Move the room object to the **index 0** of your array.
    4.  If the room doesn't exist in the local list (e.g., first message in a new chat), trigger a fresh `GET /chat/rooms` fetch.

---

## 4. WebSocket Event Summary Table

| Feature | WS Event Type | Key Payload Fields |
| :--- | :--- | :--- |
| **New Message** | `message` | Full message object |
| **Room Order** | `room_updated` | `roomId`, `lastMessage`, `lastUpdated` |
| **Edit** | `message_edited` | `messageId`, `content` |
| **Delete** | `message_deleted` | `messageId` |
| **Reactions** | `reaction_updated` | `messageId`, `userId`, `emoji` |
| **Read Status**| `room_read` | `readBy` (blue tick all messages) |
