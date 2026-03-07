import Foundation

public enum SummaryLanguageCode: String, Sendable {
  case english, zhTW, zhCN, japanese, korean, spanish, french, german

  var systemPrompt: String {
    switch self {
    case .english:
      return """
        You are a concise article summarizer. Summarize the following article \
        in 2-3 sentences. Focus on the key points and main argument.
        """
    case .zhTW:
      return """
        你必須用繁體中文回答，禁止使用英文。\
        你是一個精簡的文章摘要助手。請用台灣繁體中文將以下文章摘要為 2-3 句話。\
        使用台灣慣用的用語和語氣（例如：用「資料」不用「数据」，用「軟體」不用「软件」，\
        用「網路」不用「网络」）。聚焦於關鍵論點和主要結論。只輸出中文摘要，不要加任何前綴或解釋。
        """
    case .zhCN:
      return """
        你必须用简体中文回答，禁止使用英文。\
        你是一个简洁的文章摘要助手。请用简体中文将以下文章摘要为 2-3 句话。\
        聚焦于关键论点和主要结论。只输出中文摘要，不要加任何前缀或解释。
        """
    case .japanese:
      return """
        日本語で回答してください。英語は使わないでください。\
        あなたは簡潔な記事要約アシスタントです。以下の記事を2-3文で日本語に要約してください。\
        要点と主な論点に焦点を当ててください。要約のみを出力し、前置きや説明は不要です。
        """
    case .korean:
      return """
        한국어로 답변해 주세요. 영어를 사용하지 마세요.\
        당신은 간결한 기사 요약 도우미입니다. 다음 기사를 2-3문장으로 한국어로 요약해 주세요.\
        핵심 논점과 주요 결론에 집중하세요. 요약만 출력하고, 접두어나 설명은 붙이지 마세요.
        """
    case .spanish:
      return """
        Responde solo en español. No uses inglés.\
        Eres un asistente de resúmenes de artículos. Resume el siguiente artículo \
        en 2-3 oraciones en español. Enfócate en los puntos clave y el argumento principal. \
        Solo muestra el resumen, sin prefijos ni explicaciones.
        """
    case .french:
      return """
        Réponds uniquement en français. N'utilise pas l'anglais.\
        Tu es un assistant de résumé d'articles. Résume l'article suivant \
        en 2-3 phrases en français. Concentre-toi sur les points clés et l'argument principal. \
        Affiche uniquement le résumé, sans préfixe ni explication.
        """
    case .german:
      return """
        Antworte nur auf Deutsch. Verwende kein Englisch.\
        Du bist ein prägnanter Artikel-Zusammenfasser. Fasse den folgenden Artikel \
        in 2-3 Sätzen auf Deutsch zusammen. Konzentriere dich auf die Kernpunkte und das Hauptargument. \
        Gib nur die Zusammenfassung aus, ohne Präfix oder Erklärung.
        """
    }
  }
}

public struct ArticleSummarizer: Sendable {
  private let client: OllamaClient
  private let model: String

  private static let maxInputLength = 4000

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  /// Streams a summary of the provided article text in the specified language.
  public func summarize(
    articleText: String,
    language: SummaryLanguageCode = .english
  ) async throws -> AsyncThrowingStream<String, Error> {
    let truncated = String(articleText.prefix(Self.maxInputLength))
    return try await client.generate(
      model: model,
      prompt: truncated,
      system: language.systemPrompt
    )
  }
}
