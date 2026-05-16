/// Fallback card image when a recipe has no thumbnail URL.
String kRecipePlaceholderThumb(String recipeId) =>
    'https://picsum.photos/seed/${Uri.encodeComponent(recipeId)}/640/480';
