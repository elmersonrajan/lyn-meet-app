# LYN MEET — Student

The student app for the [LYN MEET](https://github.com/elmersonrajan/lyn-meet)
classroom. Flutter, Android and iOS. Talks to the same backend the web client
does — same Socket.IO events, same mediasoup SFU, no server changes.

**This build is students only.** There is no role picker and no teacher mode.
The role is baked into the join call, and the server would refuse the rest
anyway.

## What a student can and cannot do

The limits are the server's, not the app's — they are enforced in
`backend/src/socket/index.js` and cannot be lifted from the client.

| | Student |
| --- | --- |
| Hear the class, see the whiteboard and the shared screen | yes |
| Speak | yes — **joins muted**, and locked entirely when no staff are present |
| Raise a hand | yes |
| Answer a poll | yes, once, before it closes |
| Answer a written question | yes, and reword it until the question closes |
| Publish video or share a screen | no — never sent, never relayed |
| Draw on the whiteboard | no — `requireTeacher` |
| Ask a question or close one | no — `requireStaff` |
| Record, mute others, remove anyone, change the stage | no |

A student asks a spoken question by raising their hand. The teacher asks
written ones, and a student answers those in the Q&A panel.

### Two things a student never sees

**Other students' answers.** The server sends written answers only to a second
socket.io room holding staff — students are not in it, so those answers never
reach the device. The class is told how many people have answered and nothing
more.

**A poll's answer before it closes.** Tallies, the correct set and the
correct-answer count are stripped from the payload while a poll runs. So is
*how many* options are correct, which is why the poll UI says "choose every
option you think is right" rather than "pick two".

## Running it

```bash
flutter pub get
```

```bash
flutter run --dart-define=LYNMEET_SERVER=http://59.96.57.40:5000
```

The default server is the same address, so a bare `flutter run` works too.
Point it at a laptop running the backend with, for example,
`--dart-define=LYNMEET_SERVER=http://192.168.1.55:5000` — or
`http://10.0.2.2:5000` from an Android emulator.

```bash
flutter test
```

### Why plain http

The web client is served over a self-signed certificate. Browsers let a user
click through that; a native Dart client rejects it outright. Rather than ship
a certificate override that disables validation for every host, the app talks
to the API port directly and cleartext is permitted for exactly the known
server addresses — `android/app/src/main/res/xml/network_security_config.xml`
and the `NSExceptionDomains` block in `ios/Runner/Info.plist`. Both name the
host in the open, and both carry a note to delete them once the backend has a
real domain and certificate.

CORS is not involved: a native Socket.IO client sends no `Origin` header, and
the connection is websocket-only so it never falls back to polling.

## Joining by link

A link the teacher shares opens the app with the meeting ID already filled in.
`lib/services/meeting_link.dart` is a port of the web client's `meetingLink.js`
and accepts every form it does — `?lynmeet=`, the older `?meeting=` /
`?meetingId=` / `?id=`, the `/join/ID` and `/m/ID` paths, and a bare generated
code like `kfd-8mza-qtp`. Keeping the two in step matters: one link goes to the
whole class.

The meeting ID is upper-cased before it is sent, because the server keys the
room on that exact string — lower case used to open a second, empty room with
the same name.

## How it fits together

```
lib/
├─ config/env.dart            server URL and timeouts, overridable at build time
├─ models/                    exact shapes of the server's payloads
├─ services/
│  ├─ socket_service.dart     one socket; emitAck turns {ok:false} into a throw
│  ├─ mediasoup_service.dart  device, transports, the one mic producer, consumers
│  └─ meeting_link.dart       port of the web client's link parsing
├─ state/
│  ├─ meeting_controller.dart the room: join, hydrate, and every broadcast
│  ├─ media_controller.dart   renderers and microphone state
│  └─ whiteboard_controller.dart
├─ screens/                   join · room · ended
└─ widgets/                   stage, board, inset, people, Q&A, poll, controls
```

Models are written against the server's payloads and accept the older shape
where one existed — `Poll` reads both a single `correctIndex`/`myVote` and the
current `correct`/`myVote` sets, because a client that understands only one
shape fails silently: the vote goes through and never appears.

### The join sequence

1. `join-room {name, meetingId, role: "student"}`
2. The acknowledgement carries the **entire room** — router capabilities, ICE
   servers, participants, questions, polls, the whole whiteboard, stage mode,
   recording state and every current producer. A student joining an hour late
   is caught up in one round trip.
3. Device loads, receive transport first, then send.
4. The microphone is published and the server immediately pauses it, replying
   `joined-muted`.
5. Every producer from the acknowledgement is consumed, then each
   `new-producer` as it arrives.

Receive is built before send on purpose: a refused microphone permission must
not cost a student the lesson.

### Three separate things mute a student

`joined-muted` on arrival, `mic-locked` when the last teacher or coordinator
leaves, and `force-mute` when the teacher presses Mute All. Unmuting is
`resume-producer`, never a re-produce — pausing keeps the producer id stable so
the teacher's participant list does not flicker.

### The whiteboard is free

The server normalises stored strokes to `nx`/`ny` in 0..1, so replaying the
board on a phone is a straight multiply by the canvas size, with no knowledge
of the teacher's screen needed. Live strokes are relayed unnormalised and fall
back to `canvasWidth`/`canvasHeight`. Both paths are covered in
`test/stroke_test.dart`.

## Known constraints

- **`mediasoup_client_flutter` is abandoned** — pinned to Dart 2 and
  `flutter_webrtc ^0.9`, so it will not resolve on a current toolchain. This
  app uses `mediasfu_mediasoup_client`, the maintained fork. It is a community
  package, and it is the one dependency worth watching.
- `RTCIceServer` is not re-exported by that package's public library, so
  `mediasoup_service.dart` imports it from `src/` with an `ignore` comment.
  TURN credentials cannot be passed without it, and without TURN a student on
  mobile data gets signalling, chat and the whiteboard but no audio or video —
  a failure that looks like a video bug and is a network one.
- The `clip` stage mode shows a placeholder. Clip playback is web-only.
- **Not yet tested against a live server.** The backend needs Linux — mediasoup
  has no Windows worker — so the handshake has been verified against the
  package API and the server's event contract, not against a running room.
