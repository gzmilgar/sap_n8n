using OrderService from '../srv/order-service';

/* ------------------------------------------------------------------
 * Fiori Elements annotations - drives the `cds watch` preview app.
 * Labels are Turkish (audience-facing), identifiers stay English.
 * ------------------------------------------------------------------ */

annotate OrderService.Orders with @(
  UI: {
    HeaderInfo      : {
      TypeName      : 'Sipariş',
      TypeNamePlural: 'Siparişler',
      Title         : {Value: customer},
      Description   : {Value: product}
    },

    SelectionFields : [
      status,
      customer,
      product
    ],

    PresentationVariant: {
      SortOrder     : [{Property: createdAt, Descending: true}],
      Visualizations: ['@UI.LineItem']
    },

    LineItem        : [
      {
        $Type: 'UI.DataField',
        Value: customer,
        Label: 'Müşteri'
      },
      {
        $Type: 'UI.DataField',
        Value: product,
        Label: 'Ürün'
      },
      {
        $Type: 'UI.DataField',
        Value: qty,
        Label: 'Adet'
      },
      {
        $Type: 'UI.DataField',
        Value: amount,
        Label: 'Tutar'
      },
      {
        $Type      : 'UI.DataField',
        Value      : status,
        Criticality: statusCriticality,
        Label      : 'Durum'
      },
      {
        $Type: 'UI.DataField',
        Value: approvedBy,
        Label: 'Onaylayan'
      },
      {
        $Type: 'UI.DataField',
        Value: approvedAt,
        Label: 'Onay Zamanı'
      }
    ],

    FieldGroup #Genel: {Data: [
      {Value: customer},
      {Value: product},
      {Value: qty},
      {Value: amount},
      {Value: currency},
      {Value: createdAt}
    ]},

    FieldGroup #Onay : {Data: [
      {
        Value      : status,
        Criticality: statusCriticality
      },
      {Value: approvedBy},
      {Value: approvedAt},
      {Value: note}
    ]},

    Facets          : [
      {
        $Type : 'UI.ReferenceFacet',
        ID    : 'GenelFacet',
        Label : 'Genel Bilgiler',
        Target: '@UI.FieldGroup#Genel'
      },
      {
        $Type : 'UI.ReferenceFacet',
        ID    : 'OnayFacet',
        Label : 'Onay Bilgileri',
        Target: '@UI.FieldGroup#Onay'
      }
    ]
  }
) {
  ID                @UI.Hidden;
  statusCriticality @UI.Hidden;
  customer          @title: 'Müşteri';
  product           @title: 'Ürün';
  qty               @title: 'Adet';
  amount            @title: 'Tutar'  @Measures.ISOCurrency: currency;
  currency          @title: 'Para Birimi';
  status            @title: 'Durum';
  approvedBy        @title: 'Onaylayan';
  approvedAt        @title: 'Onay Zamanı';
  note              @title: 'Not';
  createdAt         @title: 'Oluşturma Zamanı';
  createdBy         @UI.Hidden;
  modifiedAt        @UI.Hidden;
  modifiedBy        @UI.Hidden;
}

annotate OrderService.Customers with {
  ID   @title: 'Müşteri No';
  name @title: 'Müşteri Adı';
  city @title: 'Şehir';
}

annotate OrderService.Products with {
  ID        @title: 'Ürün No';
  name      @title: 'Ürün Adı';
  unitPrice @title: 'Birim Fiyat';
}
