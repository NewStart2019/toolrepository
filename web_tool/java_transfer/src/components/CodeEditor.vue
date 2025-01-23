<template>
  <div class="code-editor-container">
    <div class="toolbar">
      <select v-model="selectedTheme">
        <option v-for="theme in themes" :key="theme.label" :value="theme.value">
          {{ theme.label }}
        </option>
      </select>
      <button @click="copyCode">复制代码</button>
    </div>

    <code-mirror
        v-model="code"
        basic
        :lang="lang"
        :phrases="phrases"
        :theme="selectedTheme"
    />
  </div>
</template>

<script lang="ts" setup>
import { ref, type Ref } from 'vue';

// Load component
import CodeMirror from 'vue-codemirror6';

// CodeMirror extensions
import { markdown as md } from '@codemirror/lang-markdown';
import {json} from '@codemirror/lang-json';
import {javascript} from '@codemirror/lang-javascript'

import type { LanguageSupport } from '@codemirror/language';
import {oneDark} from "@codemirror/theme-one-dark";

// const props = defineProps({
//   lang: {
//     type: String,
//     default: 'javascript',
//   }
// })
// const languageData = {
//   javascript: javascript(),
//   json: json(),
// }
// let currentLanguage: LanguageSupport = md();
const lang: LanguageSupport = md();
// const currentLanguage = ref(languageData[props.lang]);
const themes = [
  { label: 'One Dark', value: oneDark },
];
const selectedTheme = ref(oneDark);
const code = ref(`function example() {\n  console.log("Hello, world!");\n}`);

const phrases: Record<string, string> = {
  // @codemirror/view
  'Control character': '制御文字',
  // @codemirror/commands
  'Selection deleted': '選択を削除',
  // @codemirror/language
  'Folded lines': '折り畳まれた行',
  'Unfolded lines': '折り畳める行',
  to: '行き先',
  'folded code': '折り畳まれたコード',
  unfold: '折り畳みを解除',
  'Fold line': '行を折り畳む',
  'Unfold line': '行の折り畳む解除',
  // @codemirror/search
  'Go to line': '行き先の行',
  go: 'OK',
  Find: '検索',
  Replace: '置き換え',
  next: '▼',
  previous: '▲',
  all: 'すべて',
  'match case': '一致条件',
  'by word': '全文検索',
  regexp: '正規表現',
  replace: '置き換え',
  'replace all': 'すべてを置き換え',
  close: '閉じる',
  'current match': '現在の一致',
  'replaced $ matches': '$ 件の一致を置き換え',
  'replaced match on line $': '$ 行の一致を置き換え',
  'on line': 'した行',
  // @codemirror/autocomplete
  Completions: '自動補完',
  // @codemirror/lint
  Diagnostics: 'エラー',
  'No diagnostics': 'エラーなし',
};

const copyCode = async () => {
  try {
    await navigator.clipboard.writeText(code.value);
    alert('代码已复制到剪贴板！');
  } catch (err) {
    alert('复制失败，请手动复制！');
  }
};

</script>

<style lang="scss" scoped>
.code-editor-container {
  position: relative;
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100%;
}

.toolbar {
  display: flex;
  gap: 10px;
  padding: 10px;
  background-color: #fff;
  box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
  z-index: 10;
}

.toolbar select,
.toolbar button {
  padding: 5px 10px;
  font-size: 14px;
  border: 1px solid #ccc;
  border-radius: 4px;
  cursor: pointer;
}

.editor {
  flex-grow: 1;
  height: 100%;
  background: #f5f5f5;
}
</style>