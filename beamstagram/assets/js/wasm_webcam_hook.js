// Encodes a Uint8Array to base64 in chunks to avoid call stack overflow.
function toBase64(uint8Array) {
  let binary = "";
  const chunkSize = 8192;
  for (let i = 0; i < uint8Array.length; i += chunkSize) {
    const chunk = uint8Array.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

export const WebcamHookMount = (hook) => {
  const video = document.getElementById("webcam-video");
  const canvas = document.getElementById("webcam-canvas");
  const outputCanvas = document.getElementById("webcam-output");
  const context = canvas.getContext("2d", { willReadFrequently: true });
  const outputContext = outputCanvas.getContext("2d");

  canvas.width = +video.getAttribute("width");
  canvas.height = +video.getAttribute("height");

  let imageData = outputContext.createImageData(canvas.width, canvas.height);
  let waitingForResponse = false;

  // Receive processed frame from the server and draw it.
  hook.handleEvent("frame_processed", ({ data }) => {
    const bytes = Uint8Array.from(atob(data), (c) => c.charCodeAt(0));
    imageData.data.set(bytes);
    outputContext.putImageData(imageData, 0, 0);
    waitingForResponse = false;
  });

  function processFrame() {
    if (video.videoWidth === 0) {
      requestAnimationFrame(processFrame);
      return;
    }

    context.drawImage(video, 0, 0, canvas.width, canvas.height);

    const filterKind = video.getAttribute("data-filter-kind");

    if (!filterKind || filterKind === "" || filterKind === "nil") {
      // No filter: display the raw webcam frame directly.
      const inputData = context.getImageData(0, 0, canvas.width, canvas.height);
      imageData.data.set(inputData.data);
      outputContext.putImageData(imageData, 0, 0);
    } else if (!waitingForResponse) {
      // Send frame to server for EXLA processing.
      waitingForResponse = true;
      const inputData = context.getImageData(0, 0, canvas.width, canvas.height);
      const base64 = toBase64(new Uint8Array(inputData.data.buffer));
      hook.pushEvent("process_frame", { data: base64 });
    }

    requestAnimationFrame(processFrame);
  }

  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    navigator.mediaDevices
      .getUserMedia({ video: true })
      .then((stream) => {
        video.srcObject = stream;
        requestAnimationFrame(processFrame);
      })
      .catch((error) => console.error("Webcam access error:", error));
  }
};

export const WebcamHookDestroy = (_hook) => {};
