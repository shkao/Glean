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
        "이 기사는"으로 시작하지 말고, 내용으로 바로 들어가세요. 요약만 출력.
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

  /// System prompt for refining an existing summary with new content.
  var refineSystemPrompt: String {
    switch self {
    case .english:
      return """
        You have a draft summary of an article, and new content from a later section. \
        Rewrite the summary to incorporate the new information. Keep it 3-5 sentences. \
        Be specific with numbers, names, and results. Output only the updated summary.
        """
    case .zhTW:
      return """
        你必須用繁體中文回答。你有一篇文章的初稿摘要，以及後續段落的新內容。\
        請改寫摘要以納入新資訊。保持 3-5 句。具體提及數字、名稱和結果。只輸出更新後的摘要。
        """
    case .zhCN:
      return """
        你必须用简体中文回答。你有一篇文章的初稿摘要，以及后续段落的新内容。\
        请改写摘要以纳入新信息。保持 3-5 句。具体提及数字、名称和结果。只输出更新后的摘要。
        """
    case .japanese:
      return """
        日本語で回答。記事の要約の下書きと、後続セクションの新しい内容があります。\
        新情報を組み込んで要約を書き直してください。3-5文。更新された要約のみ出力。
        """
    case .korean:
      return """
        한국어로 답변. 기사 요약 초안과 이후 섹션의 새로운 내용이 있습니다.\
        새 정보를 반영하여 요약을 다시 작성하세요. 3-5문장. 업데이트된 요약만 출력.
        """
    case .spanish:
      return """
        Responde en español. Tienes un borrador de resumen y contenido nuevo de una sección posterior. \
        Reescribe el resumen incorporando la nueva información. 3-5 oraciones. Solo el resumen actualizado.
        """
    case .french:
      return """
        Réponds en français. Tu as un brouillon de résumé et du nouveau contenu d'une section suivante. \
        Réécris le résumé en intégrant les nouvelles informations. 3-5 phrases. Uniquement le résumé mis à jour.
        """
    case .german:
      return """
        Antworte auf Deutsch. Du hast einen Zusammenfassungsentwurf und neuen Inhalt aus einem späteren Abschnitt. \
        Schreibe die Zusammenfassung unter Einbeziehung der neuen Informationen um. 3-5 Sätze. Nur die aktualisierte Zusammenfassung.
        """
    }
  }
}

/// Summarizes articles using rolling refinement for long content.
///
/// Short articles (< 10K chars) get a single streaming pass.
/// Long articles are split into chunks. The first chunk is summarized and
/// streamed immediately, then each subsequent chunk refines the summary.
/// The user sees output after just the first chunk (~2 seconds).
public struct ArticleSummarizer: Sendable {
  private let client: OllamaClient
  private let model: String

  /// Articles under this threshold use a single LLM call.
  private static let singlePassThreshold = 10_000
  /// Characters per chunk for long articles.
  private static let chunkSize = 8_000

  public init(client: OllamaClient, model: String) {
    self.client = client
    self.model = model
  }

  public enum SummaryPhase: Sendable {
    case summarizing
    case refining(chunk: Int, total: Int)
  }

  /// Summarizes article text. Streams tokens for immediate display.
  /// For long articles, uses rolling refinement: summarize first chunk,
  /// then refine with each subsequent chunk.
  ///
  /// - Parameters:
  ///   - onPhase: Called when the summarization phase changes.
  ///   - onReplace: Called with a complete replacement summary after each
  ///     refinement pass. The caller should replace (not append) the displayed text.
  public func summarize(
    articleText: String,
    title: String = "",
    language: SummaryLanguageCode = .english,
    onPhase: (@Sendable (SummaryPhase) -> Void)? = nil,
    onReplace: (@Sendable (String) -> Void)? = nil
  ) async throws -> AsyncThrowingStream<String, Error> {
    let text = articleText.trimmingCharacters(in: .whitespacesAndNewlines)

    // Short articles: single streaming pass
    if text.count <= Self.singlePassThreshold {
      onPhase?(.summarizing)
      return try await streamSummary(text: text, title: title, language: language)
    }

    // Long articles: rolling refinement
    let chunks = Self.splitIntoChunks(text)

    // Stream the first chunk's summary (user sees output immediately)
    onPhase?(.summarizing)
    let firstStream = try await streamSummary(
      text: chunks[0], title: title, language: language
    )

    // Wrap in a new stream that also handles refinement of subsequent chunks
    return AsyncThrowingStream { continuation in
      let task = Task {
        do {
          // Phase 1: Stream first chunk summary, collect the full text
          var currentSummary = ""
          for try await token in firstStream {
            currentSummary += token
            continuation.yield(token)
          }

          // Phase 2: Refine with remaining chunks (non-streaming, replace)
          for i in 1..<chunks.count {
            onPhase?(.refining(chunk: i + 1, total: chunks.count))

            let refined = try await refine(
              currentSummary: currentSummary,
              newContent: chunks[i],
              title: title,
              language: language
            )

            currentSummary = refined
            onReplace?(refined)
          }

          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in task.cancel() }
    }
  }

  // MARK: - Private

  private func streamSummary(
    text: String,
    title: String,
    language: SummaryLanguageCode
  ) async throws -> AsyncThrowingStream<String, Error> {
    var prompt = ""
    if !title.isEmpty {
      prompt += "Title: \(title)\n\n"
    }
    prompt += text
    return try await client.generate(
      model: model,
      prompt: prompt,
      system: language.systemPrompt
    )
  }

  private func refine(
    currentSummary: String,
    newContent: String,
    title: String,
    language: SummaryLanguageCode
  ) async throws -> String {
    let prompt = """
    Current summary:
    \(currentSummary)

    New content from the article "\(title)":
    \(newContent)
    """
    return try await client.generateFull(
      model: model,
      prompt: prompt,
      system: language.refineSystemPrompt
    )
  }

  static func splitIntoChunks(_ text: String) -> [String] {
    let chars = Array(text)
    let total = chars.count
    guard total > chunkSize else { return [text] }

    var chunks: [String] = []
    var start = 0

    while start < total {
      var end = min(start + chunkSize, total)

      // Break at paragraph or sentence boundary
      if end < total {
        let searchStart = max(end - 300, start)
        let searchRange = searchStart..<end
        if let pb = lastIndex(of: "\n\n", in: chars, range: searchRange) {
          end = pb + 2
        } else if let sb = lastSentenceBreak(in: chars, range: searchRange) {
          end = sb + 1
        }
      }

      let chunk = String(chars[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !chunk.isEmpty {
        chunks.append(chunk)
      }
      start = end
    }

    return chunks
  }

  private static func lastIndex(of target: String, in chars: [Character], range: Range<Int>) -> Int? {
    let targetChars = Array(target)
    guard targetChars.count <= range.count else { return nil }
    for i in stride(from: range.upperBound - targetChars.count, through: range.lowerBound, by: -1) {
      var match = true
      for j in 0..<targetChars.count {
        if chars[i + j] != targetChars[j] { match = false; break }
      }
      if match { return i }
    }
    return nil
  }

  private static func lastSentenceBreak(in chars: [Character], range: Range<Int>) -> Int? {
    for i in stride(from: range.upperBound - 1, through: range.lowerBound, by: -1) {
      if [".", "!", "?", "\n"].contains(chars[i]) { return i }
    }
    return nil
  }
}
