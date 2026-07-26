import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { google } from "googleapis";

if (!process.argv.includes("--confirm")) throw new Error("Añade --confirm para crear o actualizar los productos de Google Play.");

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const keyFile = path.join(root, "credentials/google-play-service-account.json");
if (!existsSync(keyFile)) throw new Error(`No se encontró ${keyFile}`);

const packageName = "com.matchpoint.clubs";
const products = [
  {
    sku: "coach_ad_7_days",
    priceMicros: "4990000",
    title: "Anuncio de entrenador · 7 días",
    description: "Publica tu perfil profesional en el muro de entrenadores de MatchPoint Tennis durante 7 días."
  },
  {
    sku: "coach_ad_30_days",
    priceMicros: "12990000",
    title: "Anuncio de entrenador · 30 días",
    description: "Publica tu perfil profesional en el muro de entrenadores de MatchPoint Tennis durante 30 días."
  },
  {
    sku: "private_league_create",
    priceMicros: "6990000",
    title: "Crear una liga privada",
    description: "Crea una liga privada permanente e invita a tus amigos a competir en MatchPoint Tennis."
  }
];

const auth = new google.auth.GoogleAuth({ keyFile, scopes: ["https://www.googleapis.com/auth/androidpublisher"] });
const publisher = google.androidpublisher({ version: "v3", auth });

function moneyFromMicros(currencyCode, priceMicros) {
  const micros = BigInt(priceMicros);
  return {
    currencyCode,
    units: String(micros / 1_000_000n),
    nanos: Number((micros % 1_000_000n) * 1_000n)
  };
}

for (const product of products) {
  const eurPrice = moneyFromMicros("EUR", product.priceMicros);
  const converted = await publisher.monetization.convertRegionPrices({
    packageName,
    requestBody: { price: eurPrice }
  });

  const regionalPricingAndAvailabilityConfigs = Object.values(converted.data.convertedRegionPrices || {}).map((region) => ({
    regionCode: region.regionCode,
    price: region.price?.currencyCode === "EUR" ? eurPrice : region.price,
    availability: "AVAILABLE"
  }));

  const purchaseOptionId = "standard";
  const requestBody = {
    packageName,
    productId: product.sku,
    listings: [
      // La ficha de Play usa es-419 como idioma predeterminado. Google exige
      // que todo producto tenga una publicación en ese idioma exacto.
      { languageCode: "es-419", title: product.title, description: product.description },
      { languageCode: "es-ES", title: product.title, description: product.description }
    ],
    purchaseOptions: [{
      purchaseOptionId,
      buyOption: { legacyCompatible: true, multiQuantityEnabled: false },
      regionalPricingAndAvailabilityConfigs,
      newRegionsConfig: {
        availability: "AVAILABLE",
        usdPrice: converted.data.convertedOtherRegionsPrice.usdPrice,
        eurPrice
      }
    }]
  };

  const response = await publisher.monetization.onetimeproducts.patch({
    packageName,
    productId: product.sku,
    allowMissing: true,
    updateMask: "listings,purchaseOptions",
    "regionsVersion.version": converted.data.regionVersion.version,
    requestBody
  });

  const option = response.data.purchaseOptions?.find((candidate) => candidate.purchaseOptionId === purchaseOptionId);
  if (option?.state !== "ACTIVE") {
    await publisher.monetization.onetimeproducts.purchaseOptions.batchUpdateStates({
      packageName,
      productId: product.sku,
      requestBody: {
        requests: [{
          activatePurchaseOptionRequest: { packageName, productId: product.sku, purchaseOptionId }
        }]
      }
    });
  }

  console.log(JSON.stringify({
    productId: response.data.productId,
    purchaseOptionId,
    status: "ACTIVE",
    eurPrice
  }));
}
