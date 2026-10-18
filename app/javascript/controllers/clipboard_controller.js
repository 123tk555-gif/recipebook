import { Controller } from "@hotwired/stimulus"

// URL をコピーするボタン。コピーできたかどうかを文字で知らせる
// (コピーできない環境では、入力欄を選択して手でコピーできるようにする)
export default class extends Controller {
  static targets = ["source", "status"]

  async copy() {
    const text = this.sourceTarget.value
    try {
      await navigator.clipboard.writeText(text)
      this.statusTarget.textContent = "URL をコピーしました。"
    } catch {
      this.sourceTarget.focus()
      this.sourceTarget.select()
      this.statusTarget.textContent = "自動でコピーできませんでした。選択した URL をコピーしてください(Ctrl + C)。"
    }
  }
}
