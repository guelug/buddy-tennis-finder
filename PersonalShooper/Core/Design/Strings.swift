import SwiftUI

struct Strings {
    // MARK: - App
    static func appName(_ language: Language) -> String {
        localized("app_name", language)
    }

    // MARK: - Tabs
    static func tabHome(_ language: Language) -> String {
        localized("tab_home", language)
    }

    static func tabChat(_ language: Language) -> String {
        localized("tab_chat", language)
    }

    static func tabCloset(_ language: Language) -> String {
        localized("tab_closet", language)
    }

    static func tabTryOn(_ language: Language) -> String {
        localized("tab_tryon", language)
    }

    static func tabProfile(_ language: Language) -> String {
        localized("tab_profile", language)
    }

    static func tabAR(_ language: Language) -> String {
        localized("tab_ar", language)
    }

    // MARK: - Home
    static func homeGreeting(_ language: Language, name: String) -> String {
        let template = localized("home_greeting", language)
        return template.replacingOccurrences(of: "{name}", with: name)
    }

    static func homeQuickActions(_ language: Language) -> String {
        localized("home_quick_actions", language)
    }

    static func homeStartChat(_ language: Language) -> String {
        localized("home_start_chat", language)
    }

    static func homeTryOn(_ language: Language) -> String {
        localized("home_try_on", language)
    }

    static func homeViewPalette(_ language: Language) -> String {
        localized("home_view_palette", language)
    }

    static func homeRecentConversations(_ language: Language) -> String {
        localized("home_recent_conversations", language)
    }

    static func homeViewAll(_ language: Language) -> String {
        localized("home_view_all", language)
    }

    static func homeNoConversations(_ language: Language) -> String {
        localized("home_no_conversations", language)
    }

    static func homeStartChatting(_ language: Language) -> String {
        localized("home_start_chatting", language)
    }

    static func homeSetupProfile(_ language: Language) -> String {
        localized("home_setup_profile", language)
    }

    static func homeTitle(_ language: Language) -> String {
        switch language {
        case .english: return "Home"
        case .spanish: return "Inicio"
        }
    }

    // MARK: - Chat
    static func chatPlaceholder(_ language: Language) -> String {
        localized("chat_placeholder", language)
    }

    static func chatSend(_ language: Language) -> String {
        localized("chat_send", language)
    }

    static func chatNewConversation(_ language: Language) -> String {
        localized("chat_new_conversation", language)
    }

    static func chatHistory(_ language: Language) -> String {
        localized("chat_conversation_history", language)
    }

    // MARK: - Try On
    static func tryOnTitle(_ language: Language) -> String {
        localized("tryon_title", language)
    }

    static func tryOnCaptureClothing(_ language: Language) -> String {
        localized("tryon_capture_clothing", language)
    }

    static func tryOnCaptureSelf(_ language: Language) -> String {
        localized("tryon_capture_self", language)
    }

    static func tryOnProcessing(_ language: Language) -> String {
        localized("tryon_processing", language)
    }

    static func tryOnResultTitle(_ language: Language) -> String {
        localized("tryon_result_title", language)
    }

    // MARK: - Profile
    static func profileTitle(_ language: Language) -> String {
        localized("profile_title", language)
    }

    static func profilePhotosTitle(_ language: Language) -> String {
        localized("profile_photos_title", language)
    }

    static func profilePaletteTitle(_ language: Language) -> String {
        localized("profile_palette_title", language)
    }

    // MARK: - Privacy
    static func privacyNoticeTitle(_ language: Language) -> String {
        localized("privacy_notice_title", language)
    }

    static func privacyConsent(_ language: Language) -> String {
        localized("privacy_consent", language)
    }

    // MARK: - Subscription
    static func subscriptionTitle(_ language: Language) -> String {
        localized("subscription_title", language)
    }

    static func subscriptionFreeTier(_ language: Language) -> String {
        localized("subscription_free_tier", language)
    }

    static func subscriptionPremiumTier(_ language: Language) -> String {
        localized("subscription_premium_tier", language)
    }

    // MARK: - Common
    static func cancelButton(_ language: Language) -> String {
        localized("cancel_button", language)
    }

    static func saveButton(_ language: Language) -> String {
        localized("save_button", language)
    }

    static func continueButton(_ language: Language) -> String {
        localized("continue_button", language)
    }

    static func doneButton(_ language: Language) -> String {
        localized("done_button", language)
    }

    static func errorGeneric(_ language: Language) -> String {
        localized("error_generic", language)
    }

    // MARK: - Greetings
    static func greetingMorning(_ language: Language, name: String) -> String {
        switch language {
        case .english:
            return "Good morning, \(name)"
        case .spanish:
            return "Buenos días, \(name)"
        }
    }

    static func greetingAfternoon(_ language: Language, name: String) -> String {
        switch language {
        case .english:
            return "Good afternoon, \(name)"
        case .spanish:
            return "Buenas tardes, \(name)"
        }
    }

    static func greetingEvening(_ language: Language, name: String) -> String {
        switch language {
        case .english:
            return "Good evening, \(name)"
        case .spanish:
            return "Buenas noches, \(name)"
        }
    }

    static func guestUser(_ language: Language) -> String {
        localized("guest_user", language)
    }

    static func photoFaceCloseup(_ language: Language) -> String {
        localized("photo_face_closeup", language)
    }

    static func photoFaceProfile(_ language: Language) -> String {
        localized("photo_face_profile", language)
    }

    static func photoBodyFront(_ language: Language) -> String {
        localized("photo_body_front", language)
    }

    static func photoBodyBack(_ language: Language) -> String {
        localized("photo_body_back", language)
    }

    static func photosAllUploaded(_ language: Language) -> String {
        localized("photos_all_uploaded", language)
    }

    static func photosUploadPrompt(_ language: Language) -> String {
        localized("photos_upload_prompt", language)
    }

    static func editProfile(_ language: Language) -> String {
        localized("edit_profile", language)
    }

    static func myColorPalette(_ language: Language) -> String {
        localized("my_color_palette", language)
    }

    static func language(_ language: Language) -> String {
        localized("language", language)
    }

    static func selectLanguage(_ language: Language) -> String {
        localized("select_language", language)
    }

    static func privacy(_ language: Language) -> String {
        localized("privacy", language)
    }

    static func yourPersonalPalette(_ language: Language) -> String {
        localized("your_personal_palette", language)
    }

    static func recommendedColors(_ language: Language) -> String {
        localized("recommended_colors", language)
    }

    static func myPalette(_ language: Language) -> String {
        localized("my_palette", language)
    }

    // MARK: - Closet
    static func closetTitle(_ language: Language) -> String {
        localized("closet_title", language)
    }

    static func closetAll(_ language: Language) -> String {
        localized("closet_all", language)
    }

    static func closetNoItems(_ language: Language) -> String {
        localized("closet_no_items", language)
    }

    static func closetAddItems(_ language: Language) -> String {
        localized("closet_add_items", language)
    }

    static func closetAddArticle(_ language: Language) -> String {
        localized("closet_add_article", language)
    }

    static func closetSearch(_ language: Language) -> String {
        localized("closet_search", language)
    }

    static func closetDelete(_ language: Language) -> String {
        localized("closet_delete", language)
    }

    // MARK: - Try On
    static func tryOnTakePhotoClothing(_ language: Language) -> String {
        localized("tryon_take_photo_clothing", language)
    }

    static func tryOnTakePhotoSelf(_ language: Language) -> String {
        localized("tryon_take_photo_self", language)
    }

    static func tryOnStartTrial(_ language: Language) -> String {
        localized("tryon_start_trial", language)
    }

    static func tryonCaptureClothingDesc(_ language: Language) -> String {
        localized("tryon_capture_clothing_desc", language)
    }

    static func tryonCaptureSelfDesc(_ language: Language) -> String {
        localized("tryon_capture_self_desc", language)
    }

    static func tryOnProcessingDesc(_ language: Language) -> String {
        localized("tryon_processing_desc", language)
    }

    static func downloadToPhotos(_ language: Language) -> String {
        localized("download_to_photos", language)
    }

    static func tryAgain(_ language: Language) -> String {
        localized("try_again", language)
    }

    static func takePhotoClothing(_ language: Language) -> String {
        localized("take_photo_clothing", language)
    }

    static func takePhotoSelf(_ language: Language) -> String {
        localized("take_photo_self", language)
    }

    // MARK: - Chat
    static func chatStyleAssistant(_ language: Language) -> String {
        localized("chat_style_assistant", language)
    }

    static func chatAskFashion(_ language: Language) -> String {
        localized("chat_ask_fashion", language)
    }

    // MARK: - Category
    static func categoryDisplayName(_ category: ClothingCategory, _ language: Language) -> String {
        switch category {
        case .tops: return localized("category_tops", language)
        case .bottoms: return localized("category_bottoms", language)
        case .dresses: return localized("category_dresses", language)
        case .shoes: return localized("category_shoes", language)
        case .accessories: return localized("category_accessories", language)
        case .outerwear: return localized("category_outerwear", language)
        case .activewear: return localized("category_activewear", language)
        case .swimwear: return localized("category_swimwear", language)
        case .jewelry: return language == .spanish ? "Joyería" : "Jewelry"
        case .lingerie: return language == .spanish ? "Lencería" : "Lingerie"
        case .beauty: return language == .spanish ? "Belleza" : "Beauty"
        }
    }

    // MARK: - Add Item Form
    static func photoSection(_ language: Language) -> String {
        localized("photo_section", language)
    }

    static func detailsSection(_ language: Language) -> String {
        localized("details_section", language)
    }

    static func colorTagsSection(_ language: Language) -> String {
        localized("color_tags_section", language)
    }

    static func takePhoto(_ language: Language) -> String {
        localized("take_photo", language)
    }

    static func chooseFromLibrary(_ language: Language) -> String {
        localized("choose_from_library", language)
    }

    static func nameField(_ language: Language) -> String {
        localized("name_field", language)
    }

    static func categoryPicker(_ language: Language) -> String {
        localized("category_picker", language)
    }

    static func addColorPlaceholder(_ language: Language) -> String {
        localized("add_color_placeholder", language)
    }

    static func addButton(_ language: Language) -> String {
        localized("add_button", language)
    }

    // MARK: - Private
    private static func localized(_ key: String, _ language: Language) -> String {
        translations[key]?[language] ?? key
    }

    private static let translations: [String: [Language: String]] = [
        "app_name": [.english: "Personal Shopper", .spanish: "Personal Shopper"],
        "tab_home": [.english: "Home", .spanish: "Inicio"],
        "tab_chat": [.english: "Chat", .spanish: "Chat"],
        "tab_closet": [.english: "Closet", .spanish: "Armario"],
        "tab_tryon": [.english: "Try On", .spanish: "Probarselo"],
        "tab_profile": [.english: "Profile", .spanish: "Perfil"],
        "tab_ar": [.english: "AR View", .spanish: "Vista AR"],
        "home_greeting": [.english: "Hi, {name}!", .spanish: "Hola, {name}!"],
        "home_quick_actions": [.english: "Quick Actions", .spanish: "Acciones Rápidas"],
        "home_start_chat": [.english: "Chat with AI Stylist", .spanish: "Chatear con Estilista IA"],
        "home_try_on": [.english: "Virtual Try-On", .spanish: "Probador Virtual"],
        "home_view_palette": [.english: "My Color Palette", .spanish: "Mi Paleta de Colores"],
        "home_recent_conversations": [.english: "Recent Conversations", .spanish: "Conversaciones Recientes"],
        "home_view_all": [.english: "View All", .spanish: "Ver Todas"],
        "home_no_conversations": [.english: "No Conversations", .spanish: "Sin Conversaciones"],
        "home_start_chatting": [.english: "Start chatting with your AI stylist for personalized advice", .spanish: "Empieza a chatear con tu estilista IA para consejos personalizados"],
        "home_setup_profile": [.english: "Set up your profile for personalized recommendations", .spanish: "Configura tu perfil para recomendaciones personalizadas"],
        "chat_placeholder": [.english: "Ask me about fashion, colors, or style...", .spanish: "Preguntame sobre moda, colores o estilo..."],
        "chat_send": [.english: "Send", .spanish: "Enviar"],
        "chat_new_conversation": [.english: "New Conversation", .spanish: "Nueva Conversacion"],
        "chat_conversation_history": [.english: "Conversation History", .spanish: "Historial de Conversaciones"],
        "tryon_title": [.english: "Virtual Try-On", .spanish: "Probador Virtual"],
        "tryon_capture_clothing": [.english: "Take photo of clothing", .spanish: "Tomar foto de la prenda"],
        "tryon_capture_self": [.english: "Now take a photo of yourself", .spanish: "Ahora tomate una foto"],
        "tryon_processing": [.english: "Generating your look...", .spanish: "Generando tu look..."],
        "tryon_result_title": [.english: "Here's your look!", .spanish: "Aqui esta tu look!"],
        "profile_title": [.english: "Profile", .spanish: "Perfil"],
        "profile_photos_title": [.english: "Your Photos", .spanish: "Tus Fotos"],
        "profile_palette_title": [.english: "Your Color Palette", .spanish: "Tu Paleta de Colores"],
        "privacy_notice_title": [.english: "Privacy Notice", .spanish: "Aviso de Privacidad"],
        "privacy_consent": [.english: "I understand and consent", .spanish: "Entiendo y consiento"],
        "subscription_title": [.english: "Go Premium", .spanish: "Ir a Premium"],
        "subscription_free_tier": [.english: "Free", .spanish: "Gratis"],
        "subscription_premium_tier": [.english: "Premium", .spanish: "Premium"],
        "cancel_button": [.english: "Cancel", .spanish: "Cancelar"],
        "save_button": [.english: "Save", .spanish: "Guardar"],
        "continue_button": [.english: "Continue", .spanish: "Continuar"],
        "done_button": [.english: "Done", .spanish: "Hecho"],
        "error_generic": [.english: "Something went wrong. Please try again.", .spanish: "Algo salio mal. Por favor intenta de nuevo."],
        "guest_user": [.english: "Guest", .spanish: "Invitado"],
        "photo_face_closeup": [.english: "Face Close-up", .spanish: "Rostro"],
        "photo_face_profile": [.english: "Face Profile", .spanish: "Perfil"],
        "photo_body_front": [.english: "Body Front", .spanish: "Cuerpo Frente"],
        "photo_body_back": [.english: "Body Back", .spanish: "Cuerpo Atras"],
        "photos_all_uploaded": [.english: "All photos uploaded! Your custom palette is ready.", .spanish: "¡Todas las fotos subidas! Tu paleta personalizada está lista."],
        "photos_upload_prompt": [.english: "Upload 4 photos to analyze your personal color palette", .spanish: "Sube 4 fotos para analizar tu paleta de colores personal"],
        "edit_profile": [.english: "Edit Profile", .spanish: "Editar Perfil"],
        "my_color_palette": [.english: "My Color Palette", .spanish: "Mi Paleta de Colores"],
        "language": [.english: "Language", .spanish: "Idioma"],
        "select_language": [.english: "Select Language", .spanish: "Seleccionar Idioma"],
        "privacy": [.english: "Privacy", .spanish: "Privacidad"],
        "your_personal_palette": [.english: "Your Personal Palette", .spanish: "Tu Paleta Personal"],
        "recommended_colors": [.english: "Recommended Colors", .spanish: "Colores Recomendados"],
        "my_palette": [.english: "My Palette", .spanish: "Mi Paleta"],
        "closet_title": [.english: "My Closet", .spanish: "Mi Armario"],
        "closet_all": [.english: "All", .spanish: "Todas"],
        "closet_no_items": [.english: "No Items", .spanish: "Sin Artículos"],
        "closet_add_items": [.english: "Add items to your closet", .spanish: "Añade prendas a tu armario"],
        "closet_add_article": [.english: "Add Article", .spanish: "Añadir Artículo"],
        "closet_search": [.english: "Search closet", .spanish: "Buscar en armario"],
        "closet_delete": [.english: "Delete", .spanish: "Eliminar"],
        "tryon_take_photo_clothing": [.english: "Take a photo of the garment and then a selfie to see how it looks on you", .spanish: "Toma una foto de la prenda y luego una selfie para ver cómo te queda"],
        "tryon_take_photo_self": [.english: "Take a selfie", .spanish: "Tomate una selfie"],
        "tryon_start_trial": [.english: "Start Trial", .spanish: "Empezar Prueba"],
        "chat_style_assistant": [.english: "Style Assistant", .spanish: "Asistente de Estilo"],
        "chat_ask_fashion": [.english: "Ask about fashion...", .spanish: "Pregunta sobre moda..."],
        "category_tops": [.english: "Tops", .spanish: "Tops"],
        "category_bottoms": [.english: "Bottoms", .spanish: "Bottoms"],
        "category_dresses": [.english: "Dresses", .spanish: "Vestidos"],
        "category_shoes": [.english: "Shoes", .spanish: "Zapatos"],
        "category_accessories": [.english: "Accessories", .spanish: "Accesorios"],
        "category_outerwear": [.english: "Outerwear", .spanish: "Abrigos"],
        "category_activewear": [.english: "Activewear", .spanish: "Ropa Deportiva"],
        "category_swimwear": [.english: "Swimwear", .spanish: "Bañadores"],
        "photo_section": [.english: "Photo", .spanish: "Foto"],
        "details_section": [.english: "Details", .spanish: "Detalles"],
        "color_tags_section": [.english: "Color Tags", .spanish: "Etiquetas de Color"],
        "take_photo": [.english: "Take Photo", .spanish: "Tomar Foto"],
        "choose_from_library": [.english: "Choose from Library", .spanish: "Elegir de Biblioteca"],
        "name_field": [.english: "Name", .spanish: "Nombre"],
        "category_picker": [.english: "Category", .spanish: "Categoría"],
        "add_color_placeholder": [.english: "Add color", .spanish: "Añadir color"],
        "add_button": [.english: "Add", .spanish: "Añadir"],
        "tryon_capture_clothing_desc": [.english: "Take a photo of the clothing item you want to try on", .spanish: "Toma una foto de la prenda que quieres probarte"],
        "tryon_capture_self_desc": [.english: "Now take a selfie to see how it looks on you", .spanish: "Ahora tomate una selfie para ver cómo te queda"],
        "tryon_processing_desc": [.english: "Please wait while we generate your virtual try-on result", .spanish: "Por favor espera mientras generamos tu resultado de probador virtual"],
        "download_to_photos": [.english: "Download to Photos", .spanish: "Guardar en Fotos"],
        "try_again": [.english: "Try Again", .spanish: "Intentar de Nuevo"],
        "take_photo_clothing": [.english: "Take Photo of Clothing", .spanish: "Tomar Foto de Prenda"],
        "take_photo_self": [.english: "Take Selfie", .spanish: "Tomar Selfie"],
    ]
}
