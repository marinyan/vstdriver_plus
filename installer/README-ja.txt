vstdriver_plus 2.6.1.2 / 4-port edition

Windows 10/11 (x86 / x64) 用 VST2 MIDI 音源ドライバー。
本版は Falcosoft の Falcomod を基に、A〜Dの4ポートとポート別VST選択を追加しています。
ARM64は対象外です。VST音源のDLLは含まれていません。

インストール
1. CherryなどのMIDIアプリと、VST MIDI Driverの設定画面を終了します。
2. Setupを実行します。システムへのドライバー登録に管理者権限が必要です。
3. スタートメニューの VST MIDI System Synth → Configure VST MIDI Driver を開きます。
4. BasicのLoad VSTi...で、ご自身で用意したVST2 DLLを選びます。
5. Audio devicesで音声出力を設定します。ASIO2WASAPIも同梱しています。
6. Cherryなどを起動し、出力に VST MIDI Synth (port A/B/C/D) を割り当てます。

設定
BasicのPort A〜Dチェックで使うポートを選択します。全て外すとOFFです。
Individual VST settings OFF: Basicの共通VSTを有効な全ポートに適用します。
Individual VST settings ON: 有効なポートのAdvancedタブで個別にVSTを選べます。
個別設定をOFFにしてもポートごとのVSTパスは保持します。
ポート・VST変更後はMIDIアプリを再起動してください。
音声出力先・サンプルレート・バッファは共通です。

更新と削除
既存の設定は更新時も保持します。旧版の事前アンインストールは不要です。
使用中の旧ファイルは退避し、削除できなければWindows再起動時に削除します。
使用中のアプリは旧版を使い続けるため、更新後に再起動してください。
インストーラーはアプリを強制終了せず、Windowsも自動で再起動しません。
アンインストールはWindowsの「インストールされているアプリ」から行います。
VSTのDLLやユーザー設定は削除しません。

謝辞 / Acknowledgements
Falcosoft / Zoltán Bacskó に深く感謝します。
Falcomodでの音声出力、MIDIタイミング、互換性などの改良と、ソースコードの公開が、
今回の低遅延動作と機能追加の土台になっています。
https://github.com/Falcosoft/vstdriver
https://falcosoft.hu/vst_midi_driver_readme.html

元となった vstdriver とその改良を公開してくださった Chris Moeller、Brad Miller、
Christopher Snowhill (kode54)、Hermann Seib (Arakula)、DB50XG、その他の貢献者、
およびASIO2WASAPI、BASSASIO、WTL、NSISの開発者にも感謝します。
本版の追加変更はvstdriver_plus側のもので、上流による公式リリースではありません。
https://github.com/marinyan/vstdriver_plus

ライセンス
ドライバー: GNU LGPL 2.1以降 (LICENSE.txt)。上流の著作権表示を保持しています。
ASIO2WASAPI: GNU GPL v2 (ASIO2WASAPI-LICENSE.txt)。
BASSASIOはUn4seen Developmentsの別ライセンスです。商用利用・再配布条件は
https://www.un4seen.com/bass.html#asio を確認してください。
