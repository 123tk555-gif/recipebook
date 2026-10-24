import { Controller } from "@hotwired/stimulus"

// 材料・手順の枠を、ボタンで増やしたり減らしたりする。
// - 「追加」: <template> の枠を複製して末尾に足す(上限 max まで)
// - 「削除」: 保存前の枠はその場で消す。保存済みの枠は隠して _destroy=1 にする(保存したときに消える)
// - 枠の番号・並び順(position)は、増減のたびに振り直す
// - 操作の結果は、画面の文字(status)でも知らせる(スクリーンリーダーにも読まれる)
export default class extends Controller {
  static targets = ["list", "template", "row", "status", "addButton"]
  static values = { max: { type: Number, default: 50 }, name: String }

  connect() {
    // 入力ミスで画面を描き直したとき、すでに取り消した枠は、隠したままにする
    this.rowTargets.filter((row) => row.hidden).forEach((row) => this.hideRow(row))
    this.refresh()
  }

  add(event) {
    event.preventDefault()
    if (this.visibleRows().length >= this.maxValue) return

    // フォームの名前の目印(NEW_RECORD)を、重ならない数に置き換える
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", `${Date.now()}${this.counter = (this.counter || 0) + 1}`)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.refresh()

    const row = this.visibleRows().at(-1)
    row.querySelector("input[type=text], textarea")?.focus()
    const total = this.visibleRows().length
    const limit = total >= this.maxValue ? `。${this.nameValue}は${this.maxValue}個までなので、これ以上は追加できません` : ""
    this.announce(`${this.nameValue}の枠を追加しました(全${total}枠)${limit}`)
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-nested-form-target='row']")
    if (!row || this.visibleRows().length <= 1) return

    const rows = this.visibleRows()
    const index = rows.indexOf(row)
    const label = `${this.nameValue}${index + 1}`

    if (row.querySelector("input[name$='[id]']")) {
      // 保存済みの枠: 隠して、保存のときに削除する
      row.querySelector("[data-nested-form-target='destroy']").value = "1"
      this.hideRow(row)
    } else {
      row.remove()
    }
    this.refresh()

    // 消した枠の次(なければ前)の枠に、キーボードの位置を移す
    const remaining = this.visibleRows()
    const next = remaining[Math.min(index, remaining.length - 1)]
    next?.querySelector("input[type=text], textarea")?.focus()
    this.announce(`${label}の枠を削除しました(全${remaining.length}枠)。保存すると反映されます`)
  }

  // 枠を隠す。入力欄とボタンは無効にして、操作もスクリーンリーダーの読み上げも対象から外す(id・position・_destroy は送る)
  hideRow(row) {
    row.hidden = true
    row.querySelectorAll("input:not([type=hidden]), textarea, button").forEach((el) => { el.disabled = true })
  }

  // 表示している枠(削除した枠は除く)
  visibleRows() {
    return this.rowTargets.filter((row) => !row.hidden)
  }

  // 番号・並び順・ボタンの状態を振り直す
  refresh() {
    const visible = this.visibleRows()
    let order = 0
    this.rowTargets.forEach((row) => {
      row.querySelector("[data-nested-form-target='position']").value = order++
    })
    visible.forEach((row, i) => {
      const n = i + 1
      row.setAttribute("aria-label", `${this.nameValue} ${n}`)
      const removeButton = row.querySelector(".remove-row")
      removeButton.setAttribute("aria-label", `${this.nameValue} ${n} を削除`)
      removeButton.disabled = visible.length <= 1
      const label = row.querySelector("[data-nested-form-target='label']")
      if (label) label.textContent = `${this.nameValue}${n}`
    })
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = visible.length >= this.maxValue
  }

  announce(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
