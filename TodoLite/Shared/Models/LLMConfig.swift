import Foundation

struct LLMConfig: Codable, Sendable {
    var apiKey: String
    var baseURL: String
    var model: String
    /// 周报生成要求模板；为空时使用内置默认模板
    var reportTemplate: String

    init(
        apiKey: String = "",
        baseURL: String = "https://api.openai.com/v1",
        model: String = "gpt-4o-mini",
        reportTemplate: String = ""
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.reportTemplate = reportTemplate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? "https://api.openai.com/v1"
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? "gpt-4o-mini"
        reportTemplate = try container.decodeIfPresent(String.self, forKey: .reportTemplate) ?? ""
    }
}

extension LLMConfig {
    /// 内置默认周报模板（reportTemplate 为空时使用）
    static let defaultReportTemplate = """
    1. 按项目分类列出完成的工作内容，无项目的任务归入“其他”
    2. 只要工作内容，不要本周概述，也不要下周计划
    3. 使用纯文本，不要使用 Markdown 标记（如 #、**、-、表格、分隔线等）
    4. 语言简洁专业
    """
}
