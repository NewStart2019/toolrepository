<template>
  <CodeEditor :lang="language"/>
  <Test_Editor/>
</template>

<script setup lang="ts">
import CodeEditor from "./components/CodeEditor.vue";
import Test_Editor  from "./components/Test_Editor.vue";
import {ref} from "vue";

/** text */
const language = ref('javascript');
</script>

<style>
button {
  padding: 8px 16px;
  background-color: #4CAF50;
  color: white;
  border: none;
  cursor: pointer;

  &:hover {
    background-color: #31e739;
  }
}

.red {
  color: red;
}

/* 美化输入框的默认样式 */
select, input[type="text"], input[type="number"] {
  padding: 8px 12px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 16px;
  transition: border-color 0.3s ease;
}

/* 输入框获取焦点时的样式 */
select:focus, input[type="text"]:focus, input[type="number"]:focus {
  outline: none;
  border-color: #007bff;
  box-shadow: 0 0 5px rgba(0, 123, 255, 0.5);
}

input[type="number"] {
  width: 80px;
  margin-right: 10px;
}

.flex-container {
  display: flex;
  justify-content: center;

  & + div {
    margin-top: 20px;
  }

  & button {
    border-radius: 40px;
  }
}

.left-edit {
  flex: 1;
}

.right-edit {
  flex: 1;
}

.flex-col {
  flex: 1;
  align-items: center;
}

.form-row {
  display: flex;
  align-items: center;

  & label {
    margin-right: 5px;
  }

  & input[type="number"] {
    flex: 1;
  }
}

#themeSelector {
  padding: 8px 16px;
  background-color: #4CAF50;
  color: white;
  border: none;
  cursor: pointer;
  position: absolute;
  top: 5px;
  right: 132px;
  border-radius: 40px;

  &:hover {
    background-color: #45a049;
  }
}

.copy-btn {
  position: absolute;
  top: 5px;
  right: 10px;
}

.beautifyJSON {
  position: absolute;
  top: 5px;
  right: 5px;
}

.add-field {
  margin-right: 10px;
}

.CodeMirror {
  /*resize: vertical; !* 允许垂直方向调整大小 *!*/
  min-height: 70vh; /* 设置最小高度 */
}

#tutorialButton {
  color: #007bff;
  text-decoration: underline;
  cursor: pointer;
}

/* 对话框样式 */
.dialog-overlay {
  display: block;
  position: fixed; /* 修改为 fixed 定位 */
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  z-index: 999;
  overflow: auto;
}

.dialog-box {
  background-color: #fefefe;
  border: 1px solid #888;
  border-radius: 8px;
  max-width: 80%;
  padding: 20px;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  overflow: auto;
  position: absolute; /* 可以保持在页面中央 */
  left: 50%; /* 从左侧 50% 开始 */
  transform: translate(-50%, -0%); /* 将对话框向上和向左移动其宽度和高度的一半，从而使其在中心 */
}


.dialog-header {
  text-align: right; /* 右对齐 */
}

.close-button {
  cursor: pointer;
}

.dialog-content {
  margin-top: 10px; /* 顶部留白 */
  /* 添加您的富文本内容样式 */
}

pre {
  background-color: #f4f4f4;
  padding: 10px;
  border: 1px solid #ccc;
  border-radius: 5px;
  font-family: Consolas, Monaco, 'Andale Mono', 'Ubuntu Mono', monospace;
  white-space: pre-wrap;
  word-wrap: break-word;
  overflow: auto;
}
</style>
