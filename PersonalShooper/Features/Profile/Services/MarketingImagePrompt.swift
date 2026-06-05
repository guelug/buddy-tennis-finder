import Foundation

/// Builds the e-commerce "marketing thumbnail" prompt for a garment, shared by every image provider
/// so optimized closet images are *consistent*: pure white background, straight-on FRONT view,
/// centered, fully visible — with category-specific framing (e.g. shoes always shown as a full pair
/// pointing toward the viewer). This is what keeps the closet grid looking tidy and uniform.
enum MarketingImagePrompt {

    static func build(categoryHint: String) -> String {
        let framing = framingInstruction(for: categoryHint)
        return """
        Create a clean, professional e-commerce product photo of THIS EXACT \(categoryHint).
        Keep the item's color, pattern, fabric, texture, logos, and shape EXACTLY as in the source image — do not restyle, recolor, or redesign it.
        Place it on a pure white (#FFFFFF) seamless studio background, perfectly centered, evenly lit, with a soft natural drop shadow.
        ALWAYS show the FRONT of the item, photographed straight-on at eye level (a slight, consistent angle is fine), fully visible within the frame.
        \(framing)
        No mannequin, no person, no hands, no props, no text, no logos overlay, no extra items. Output a single, well-framed product image.
        """
    }

    /// Category-specific orientation/framing so every optimized image follows the same order.
    private static func framingInstruction(for categoryHint: String) -> String {
        let hint = categoryHint.lowercased()

        func matches(_ keywords: [String]) -> Bool {
            keywords.contains { hint.contains($0) }
        }

        // Footwear: a matching PAIR, side by side, both pointing toward the viewer.
        if matches(["shoe", "sneaker", "boot", "footwear", "zapato", "zapatilla", "bota", "calzado", "bamba"]) {
            return "Show the COMPLETE matching PAIR of shoes, placed side by side at the same height, BOTH shoes pointing toward the viewer with the toes forward (front or gentle three-quarter view), laces and tongue facing up. Never show a single shoe or a pure side profile."
        }
        // Tops / shirts / knitwear: front-facing as if worn.
        if matches(["top", "shirt", "camis", "blus", "jersey", "knit", "sweater", "sudader", "hoodie", "tee", "polo"]) {
            return "Show the top FRONT-FACING and symmetric, as if worn or on an invisible ghost mannequin (buttoned/zipped if applicable), shoulders level, sleeves relaxed at the sides, the whole garment visible."
        }
        // Bottoms / trousers / jeans / skirts.
        if matches(["bottom", "trouser", "pant", "jean", "panta", "falda", "skirt", "short"]) {
            return "Show the bottoms FRONT-FACING and full-length, waistband at the top and legs hanging straight and vertical, laid flat or ghost-mannequin, the whole garment visible."
        }
        // Dresses / jumpsuits.
        if matches(["dress", "vestido", "jumpsuit", "mono"]) {
            return "Show the dress FRONT-FACING and full-length, as if worn on an invisible ghost mannequin, centered and symmetric, the whole garment visible."
        }
        // Outerwear / coats / blazers / jackets.
        if matches(["outerwear", "coat", "blazer", "jacket", "abrigo", "chaqueta", "americana", "cazadora"]) {
            return "Show the outerwear FRONT-FACING, closed or buttoned, shoulders level and symmetric, the whole garment visible."
        }
        // Bags / accessories.
        if matches(["bag", "bolso", "cartera", "accessor", "accesori", "belt", "cinturón", "cinturon", "scarf", "bufanda", "hat", "gorro", "sombrero"]) {
            return "Show the accessory FRONT-FACING and upright in its natural orientation (handles or straps up for bags), centered and fully visible."
        }
        // Jewelry.
        if matches(["jewel", "joya", "ring", "anillo", "necklace", "collar", "earring", "pendiente", "bracelet", "pulsera", "watch", "reloj"]) {
            return "Show the jewelry FRONT-FACING, laid flat and centered, fully visible, with fine detail preserved."
        }
        // Fallback.
        return "Show the FULL item front-facing, centered and upright in its natural orientation."
    }
}
