// Locale presets for the common ways of writing an amount.
//
// A locale preset only sets the presentation: separators, grouping width,
// position of the symbol and how a negative is marked. It never changes the
// value, and it never fetches anything. Locales that share a layout share a row
// in the table.

///|
priv struct LocaleStyle {
  locale : String
  group_separator : String
  decimal_separator : String
  position : SymbolPosition
  space : Bool
  primary_group : Int
  secondary_group : Int
  negative : NegativeStyle
}

///|
/// The layouts the library ships. The first field is the tag the lookup accepts;
/// the language-only form of the same tag resolves here too.
let locales : Array[LocaleStyle] = [
  {
    locale: "en-US",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "en-GB",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "en-IN",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 2,
    negative: Minus,
  },
  {
    locale: "de-DE",
    group_separator: ".",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "de-AT",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "fr-FR",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "es-ES",
    group_separator: ".",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "it-IT",
    group_separator: ".",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "nl-NL",
    group_separator: ".",
    decimal_separator: ",",
    position: Before,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "pt-BR",
    group_separator: ".",
    decimal_separator: ",",
    position: Before,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "sv-SE",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "da-DK",
    group_separator: ".",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "nb-NO",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "pl-PL",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "ru-RU",
    group_separator: " ",
    decimal_separator: ",",
    position: After,
    space: true,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "zh-CN",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "zh-TW",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "ja-JP",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "ko-KR",
    group_separator: ",",
    decimal_separator: ".",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
  {
    locale: "tr-TR",
    group_separator: ".",
    decimal_separator: ",",
    position: Before,
    space: false,
    primary_group: 3,
    secondary_group: 3,
    negative: Minus,
  },
]

///|
/// The style for a locale tag such as `de-DE` or `de`.
///
/// The match ignores case and falls back to the language part, so `en-AU`
/// resolves through `en`. `None` means the library has no layout for that tag
/// and the caller should pick one rather than receive a guess.
pub fn MoneyStyle::for_locale(locale : StringView) -> MoneyStyle? {
  let wanted = locale.trim().to_upper().to_owned()
  let mut exact : LocaleStyle? = None
  let mut language : LocaleStyle? = None
  let language_part = match wanted.find("-") {
    Some(index) => wanted[0:index]
    None => wanted
  }
  for entry in locales {
    let tag = entry.locale.to_upper()
    if tag == wanted {
      exact = Some(entry)
    } else {
      let entry_language = match tag.find("-") {
        Some(index) => tag[0:index]
        None => tag
      }
      if entry_language == language_part && language is None {
        language = Some(entry)
      }
    }
  }
  match exact {
    Some(entry) => Some(style_of(entry))
    None =>
      match language {
        Some(entry) => Some(style_of(entry))
        None => None
      }
  }
}

///|
fn style_of(entry : LocaleStyle) -> MoneyStyle {
  {
    unit: Symbol,
    position: entry.position,
    space: entry.space,
    group: true,
    group_separator: entry.group_separator,
    decimal_separator: entry.decimal_separator,
    digits: None,
    primary_group: entry.primary_group,
    secondary_group: entry.secondary_group,
    negative: entry.negative,
  }
}

///|
/// The locale tags the library ships a layout for.
pub fn known_locales() -> Array[String] {
  let tags : Array[String] = []
  for entry in locales {
    tags.push(entry.locale)
  }
  tags
}
