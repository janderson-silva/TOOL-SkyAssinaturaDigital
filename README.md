# Sky Assinatura Digital

Aplicação Windows em Delphi para assinar PDFs com certificado digital. Permite visualizar as páginas, escolher o local da assinatura e salvar uma nova cópia, preservando o arquivo original.

## Funcionalidades

- Prévia do PDF e navegação entre páginas.
- Seleção de certificado instalado no Windows.
- Posicionamento da assinatura por clique.
- Ajuste de largura e altura, manualmente ou com botões de ±10 pontos.
- Assinatura criptográfica com SHA-256 e identificação visual no documento.

## Requisitos

- Windows 10/11 e Windows PowerShell 5.1 para a prévia.
- Certificado com chave privada no repositório **Usuário atual > Pessoal** do Windows. Para A1, importe o `.pfx` pelo Windows; A3 depende do driver/provedor do token.
- Delphi 10.3 ou 12 para desenvolvimento, com VCL e formulário DFM. Não exige componentes de terceiros.

Abra `SkyAssinatura.dproj` no Delphi. Mantenha `scripts/Render-Pdf.ps1` ao lado do executável, dentro da pasta `scripts` — na organização atual, `bin/scripts/Render-Pdf.ps1`.

## Como usar

1. Clique em **Abrir PDF** e selecione o documento.
2. Escolha o certificado e a página desejada.
3. Ajuste o tamanho e clique no PDF para posicionar a assinatura. Após mudar o tamanho, posicione novamente.
4. Clique em **Assinar e salvar PDF** e escolha um nome novo.

Confira a assinatura em um leitor de PDF com validação criptográfica.

## Limitações

O suporte a PDF é parcial: arquivos criptografados, com revisões incrementais, páginas rotacionadas ou certas estruturas internas não são aceitos. Limite de entrada: **200 MB**.

Não adiciona outra assinatura a documentos já assinados nem assina formulários XFA ou documentos com bloqueios/restrições não suportados. Não inclui carimbo de tempo confiável, validação de cadeia/revogação ou garantia de conformidade PAdES/ICP-Brasil. Não integra o serviço gov.br.

## Licença

[MIT](LICENSE) · Copyright (c) 2026 [Janderson Silva](https://github.com/janderson-silva).
