import Foundation

public enum SummaryLanguageCode: String, Sendable {
  case english, zhTW, zhCN, japanese, korean, spanish, french, german

  var systemPrompt: String {
    switch self {
    case .english:
      return """
        You are an expert article summarizer. Write a clear, informative summary \
        of the article below. Include: (1) the main finding or argument, \
        (2) the method or evidence used, and (3) why it matters. \
        Write 3-5 sentences. Be specific with numbers, names, and results. \
        Do not start with "This article" or "The article". Jump straight into the content.
        """
    case .zhTW:
      return """
        你必須用繁體中文回答，禁止使用英文。\
        你是一位專業的文章摘要助手。請撰寫清楚、有資訊量的摘要。\
        包含：(1) 主要發現或論點，(2) 使用的方法或證據，(3) 為什麼重要。\
        寫 3-5 句。具體提及數字、名稱和結果。\
        使用台灣慣用語（「資料」非「数据」、「軟體」非「软件」、「網路」非「网络」）。\
        不要用「本文」或「這篇文章」開頭，直接切入內容。只輸出摘要。
        """
    case .zhCN:
      return """
        你必须用简体中文回答，禁止使用英文。\
        你是一位专业的文章摘要助手。请撰写清楚、有信息量的摘要。\
        包含：(1) 主要发现或论点，(2) 使用的方法或证据，(3) 为什么重要。\
        写 3-5 句。具体提及数字、名称和结果。\
        不要用"本文"或"这篇文章"开头，直接切入内容。只输出摘要。
        """
    case .japanese:
      return """
        日本語で回答してください。英語は使わないでください。\
        あなたは専門的な記事要約アシスタントです。明確で情報量のある要約を書いてください。\
        含めるべき内容：(1) 主な発見または論点、(2) 使用された方法や証拠、(3) なぜ重要か。\
        3-5文で書いてください。数値、名前、結果を具体的に記載してください。\
        「この記事は」で始めず、内容に直接入ってください。要約のみを出力してください。
        """
    case .korean:
      return """
        한국어로 답변해 주세요. 영어를 사용하지 마세요.\
        당신은 전문 기사 요약 도우미입니다. 명확하고 정보가 풍부한 요약을 작성하세요.\
        포함할 내용: (1) 주요 발견 또는 논점, (2) 사용된 방법이나 증거, (3) 왜 중요한지.\
        3-5문장으로 작성하세요. 숫자, 이름, 결과를 구체적으로 언급하세요.\
        "이 기사는"으로 시작하지 말고, 내용으로 바로 들어가세요. 요약만 출력하세요.
        """
    case .spanish:
      return """
        Responde solo en español. No uses inglés.\
        Eres un asistente experto en resúmenes. Escribe un resumen claro e informativo.\
        Incluye: (1) el hallazgo o argumento principal, (2) el método o evidencia, \
        (3) por qué es importante. Escribe 3-5 oraciones. Sé específico con números, \
        nombres y resultados. No empieces con "Este artículo". Solo muestra el resumen.
        """
    case .french:
      return """
        Réponds uniquement en français. N'utilise pas l'anglais.\
        Tu es un assistant expert en résumés. Rédige un résumé clair et informatif.\
        Inclus: (1) la découverte ou l'argument principal, (2) la méthode ou les preuves, \
        (3) pourquoi c'est important. Écris 3-5 phrases. Sois précis avec les chiffres, \
        noms et résultats. Ne commence pas par "Cet article". Affiche uniquement le résumé.
        """
    case .german:
      return """
        Antworte nur auf Deutsch. Verwende kein Englisch.\
        Du bist ein Experte für Artikelzusammenfassungen. Schreibe eine klare, informative \
        Zusammenfassung. Enthalten: (1) das Hauptergebnis oder Argument, (2) die Methode \
        oder Evidenz, (3) warum es wichtig ist. Schreibe 3-5 Sätze. Sei spezifisch mit \
        Zahlen, Namen und Ergebnissen. Beginne nicht mit "Dieser Artikel". Nur die Zusammenfassung.
        """
    }
  }
}

public struct ArticleSummarizer: Sendable {
  private let client: OllamaClient
  private let model: String

  private static let maxInputLength = 8000

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  /// Streams a summary of the provided article text in the specified language.
  public func summarize(
    articleText: String,
    title: String = "",
    language: SummaryLanguageCode = .english
  ) async throws -> AsyncThrowingStream<String, Error> {
    let truncated = String(articleText.prefix(Self.maxInputLength))
    var prompt = ""
    if !title.isEmpty {
      prompt += "Title: \(title)\n\n"
    }
    prompt += truncated
    return try await client.generate(
      model: model,
      prompt: prompt,
      system: language.systemPrompt
    )
  }
}
