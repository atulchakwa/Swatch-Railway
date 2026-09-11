import { RekognitionClient, CompareFacesCommand, DetectLabelsCommand, DetectFacesCommand } from "@aws-sdk/client-rekognition";
import { db } from '../database/index.js';
import config from '../config/index.js';

let rekognitionClient = null;

function getRekognitionClient() {
  if (rekognitionClient) return rekognitionClient;
  const { accessKeyId, secretAccessKey, region } = config.aws;
  if (!accessKeyId || !secretAccessKey) {
    throw new Error('AWS credentials not configured for Rekognition');
  }
  rekognitionClient = new RekognitionClient({
    region: region || 'ap-south-1',
    credentials: { accessKeyId, secretAccessKey }
  });
  return rekognitionClient;
}

function getStoragePath(url) {
  try {
    const decodedUrl = decodeURIComponent(url);
    const parts = decodedUrl.split('/o/');
    if (parts.length > 1) {
      return parts[1].split('?')[0];
    }
    return null;
  } catch (e) {
    return null;
  }
}

async function downloadImage(url) {
  const path = getStoragePath(url);
  if (!path) throw new Error('Failed to extract cloud path from URL');
  const bucket = db.getBucket();
  const [buffer] = await bucket.file(path).download();
  if (!buffer || buffer.length === 0) throw new Error('Empty image buffer');
  return buffer;
}

export async function compareFaces(image1Url, image2Url) {
  try {
    if (!image1Url || !image2Url || image1Url.includes('undefined') || image2Url.includes('undefined')) {
      return { matched: false, similarity: 0, reason: 'One or both image URLs are missing or invalid.', error: true };
    }

    const rekognition = getRekognitionClient();
    const [fileBuffer1, fileBuffer2] = await Promise.all([
      downloadImage(image1Url),
      downloadImage(image2Url)
    ]);

    const command = new CompareFacesCommand({
      SourceImage: { Bytes: fileBuffer1 },
      TargetImage: { Bytes: fileBuffer2 },
      SimilarityThreshold: 60
    });

    const data = await rekognition.send(command);

    if (data.FaceMatches && data.FaceMatches.length > 0) {
      const matchScore = data.FaceMatches[0].Similarity;
      return { matched: true, similarity: matchScore, reason: 'Face matched successfully.' };
    }

    if (data.UnmatchedFaces && data.UnmatchedFaces.length > 0) {
      console.warn(`[Rekognition] Faces detected but all below 60% threshold. Unmatched: ${data.UnmatchedFaces.length}`);
    }
    return { matched: false, similarity: 0, reason: 'Face structure does not match the baseline profile selfie.' };

  } catch (awsException) {
    let errorMsg = 'Biometric analysis failed due to poor image properties.';
    if (awsException.message?.includes('contains no faces') || awsException.name === 'InvalidParameterException') {
      errorMsg = 'Face not detected! Please ensure the photo is clear, well-lit, and contains a visible human face.';
    } else if (awsException.name === 'ImageTooLargeException') {
      errorMsg = 'The uploaded file size exceeds the allowed processing dimensions.';
    }
    return { matched: false, similarity: 0, reason: errorMsg, error: true };
  }
}

export async function verifyFaceLiveness(imageUrl, expectedChallenge) {
  try {
    if (!imageUrl || imageUrl.includes('undefined')) {
      return { matched: false, reason: 'Invalid image URL.', error: true };
    }

    const rekognition = getRekognitionClient();
    const fileBuffer = await downloadImage(imageUrl);

    if (expectedChallenge === 'THUMBS_UP' || expectedChallenge === 'FIST') {
      const command = new DetectLabelsCommand({
        Image: { Bytes: fileBuffer },
        MaxLabels: 20,
        MinConfidence: 50
      });
      const data = await rekognition.send(command);
      const labels = data.Labels.map(l => l.Name.toUpperCase());

      let isMatch = false;
      if (expectedChallenge === 'THUMBS_UP' && labels.includes('THUMBS UP')) isMatch = true;
      if (expectedChallenge === 'FIST' && (labels.includes('FIST') || labels.includes('HAND') || labels.includes('FINGERS'))) isMatch = true;

      if (!isMatch) {
        return { matched: false, reason: `Could not detect ${expectedChallenge} gesture in the photo.`, error: true };
      }
      return { matched: true };
    }

    if (expectedChallenge === 'SMILE') {
      const command = new DetectFacesCommand({
        Image: { Bytes: fileBuffer },
        Attributes: ['ALL']
      });
      const data = await rekognition.send(command);
      if (!data.FaceDetails || data.FaceDetails.length === 0) {
        return { matched: false, reason: 'No face detected in the photo.' };
      }
      const face = data.FaceDetails[0];
      if (face.Smile && face.Smile.Value === true && face.Smile.Confidence > 40) {
        return { matched: true };
      }
      return { matched: false, reason: 'Could not detect a clear SMILE in the photo.' };
    }

    return { matched: true };
  } catch (err) {
    console.error('[Rekognition Liveness] Error:', err.message);
    return { matched: false, reason: 'Liveness verification failed due to internal error.', error: true };
  }
}
