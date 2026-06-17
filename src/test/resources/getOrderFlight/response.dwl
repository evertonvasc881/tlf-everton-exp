%dw 2.0
output application/json
---
{
  flagBloqueio: false,
  ordem: [
    {
      tipoOrdem: "INSTALACAO",
      numeroOrdem: "ORD-2026-00001234",
      statusOrdem: "EM_ANDAMENTO",
      dataCriacao: "2026-06-16T10:30:00Z"
    },
    {
      tipoOrdem: "MANUTENCAO",
      numeroOrdem: "ORD-2026-00005678",
      statusOrdem: "CONCLUIDA",
      dataCriacao: "2026-06-10T14:22:00Z"
    }
  ]
}
