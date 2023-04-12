class TOMLValue {
    U8 *key;
    U8 *value;
};

class TOMLSection {
    U8 *name;
    TOMLValue *values;
    U32 value_count;
};

class TOMLFile {
    TOMLSection *sections;
    U32 section_count;
};

U0 ParseLine(U8 *line, TOMLValue *value) {
    MemSet(value, 0, sizeof(TOMLValue));
    U8 *equals = StrFirstOcc(line, "=");
    if (!equals) return;

    U8 *key_start = line;
    U8 *key_end = equals - 1;
    while (key_start < key_end && *key_start == ' ') {
        key_start++;
    }
    while (key_end > key_start && *key_end == ' ') {
        key_end--;
    }

    U8 *value_start = equals + 1;
    while (*value_start == ' ') {
        value_start++;
    }

    U64 key_len = key_end - key_start + 1;
    U64 value_len = StrLen(value_start);

    value->key = MAlloc(key_len + 1);
    MemCpy(value->key, key_start, key_len);
    value->key[key_len] = 0;

    value->value = MAlloc(value_len + 1);
    MemCpy(value->value, value_start, value_len + 1);
}
U0 ParseSection(U8 *line, TOMLSection *section) {
    MemSet(section, 0, sizeof(TOMLSection)); 

    U8 *section_end = StrFirstOcc(line, "]");
    if (!section_end) return;

    U64 length = section_end - line;


    section->name = MAlloc(length);
    MemCpy(section->name, line + 1, length - 1);
    section->name[length - 1] = 0;
}


TOMLFile *ReadTOMLFile(U8 *file_path) {
  TOMLFile *toml_file = MAlloc(sizeof(TOMLFile));
  MemSet(toml_file, 0, sizeof(TOMLFile));
  toml_file->section_count = 0;
  toml_file->sections = 0;

  TOMLSection *current_section = 0;

  U64 file_size;
  U8 *file_data = FileRead(file_path, &file_size);

  if (file_data) {
    U8 *line_buf = file_data;
    U8 *file_end = file_data + file_size;
    while (line_buf < file_end) {
      U8 *next_line = StrFirstOcc(line_buf, "\n");
      if (next_line) {
        *next_line = 0;
        next_line++;
      } else {
        next_line = file_end;
      }

      if (line_buf[0] == '[') {
        TOMLSection section;
        ParseSection(line_buf, &section);
        TOMLSection *new_sections = MAlloc((toml_file->section_count + 1) * sizeof(TOMLSection));
        if (toml_file->sections) {
          MemCpy(new_sections, toml_file->sections, toml_file->section_count * sizeof(TOMLSection));
          Free(toml_file->sections);
        }
        toml_file->sections = new_sections;
        MemCpy(&toml_file->sections[toml_file->section_count], &section, sizeof(TOMLSection));
        toml_file->section_count++;
        current_section = &toml_file->sections[toml_file->section_count - 1];
        current_section->values = 0;
        current_section->value_count = 0;
      } else if (line_buf[0] != 0 && line_buf[0] != '\n') {
        TOMLValue value;
        ParseLine(line_buf, &value);
        if (value.key && value.value) {
          if (current_section) {
            TOMLValue *new_values = MAlloc((current_section->value_count + 1) * sizeof(TOMLValue));
            if (current_section->values) {
              MemCpy(new_values, current_section->values, current_section->value_count * sizeof(TOMLValue));
              Free(current_section->values);
            }
            current_section->values = new_values;
            MemCpy(&current_section->values[current_section->value_count], &value, sizeof(TOMLValue));
            current_section->value_count++;
          }
        }
      }

      line_buf = next_line;
    }
    Free(file_data);
  } else {
    Print("Failed to open file: %s\n", file_path);
  }

  return toml_file;
}


U0 FreeTOMLFile(TOMLFile *toml_file) {
  if (toml_file) {
    I64 i, j;
    for (i = 0; i < toml_file->section_count; ++i) {
      TOMLSection *section = &toml_file->sections[i];
      if (section->values) {
        for (j = 0; j < section->value_count; ++j) {
          if (section->values[j].key) {
            Free(section->values[j].key);
          }
          if (section->values[j].value) {
            Free(section->values[j].value);
          }
        }
        Free(section->values);
      }
      if (section->name) {
        Free(section->name);
      }
    }
    if (toml_file->sections) {
      Free(toml_file->sections);
    }
    Free(toml_file);
  }
}

TOMLSection *FindTOMLSection(TOMLFile *toml_file, U8 *section_name) {
    if (toml_file && section_name) {
        U32 i;
        for (i = 0; i < toml_file->section_count; ++i) {
            if (StrCmp(toml_file->sections[i].name, section_name) == 0) {
                return &toml_file->sections[i];
            }
        }
    }
    return NULL;
}

TOMLValue *FindTOMLValue(TOMLSection *section, U8 *key) {
    if (section && key) {
        U32 i;
        for (i = 0; i < section->value_count; ++i) {
            if (StrCmp(section->values[i].key, key) == 0) {
                return &section->values[i];
            }
        }
    }
    return NULL;
}

U8 *GetValue(TOMLFile *toml_file, U8 *section_name, U8 *key) {
    TOMLSection *section = FindTOMLSection(toml_file, section_name);
    if (section) {
        TOMLValue *value = FindTOMLValue(section, key);
        if (value) {
            return value->value;
        }
    }
    return NULL;
}

// Simply a debug function
U0 PrintTOMLContent(TOMLFile *toml_file) {
    U32 i, j;
    for (i = 0; i < toml_file->section_count; ++i) {
        TOMLSection *section = &toml_file->sections[i];
        "\n";
        Print("Section: %s\n", section->name);
        for (j = 0; j < section->value_count; ++j) {
            TOMLValue *value = &section->values[j];
            Print("  Key: %s, Value: %s\n", value->key, value->value);
        }
    }
}

// This isn't a permanent function.
// This is just an example of how to use this code.
U0 Bettr() {
    // Replace "path/to/your/file.toml" with the actual path to the TOML file you want to read.
    TOMLFile *toml_file = ReadTOMLFile("Example.toml");
    if (toml_file) {
        PrintTOMLContent(toml_file);
        FreeTOMLFile(toml_file);
    } else {
        Print("Failed to read TOML file.\n");
    }
}
