// 保守の productDetailsPanel.jsp の「保証期間」表示を移植したもの(検証用の雛形。ビルドはしていない)
import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { AsyncPipe } from '@angular/common';
import { CurrentProductService } from '@spartacus/storefront';
import { map } from 'rxjs';

@Component({
  selector: 'app-warranty',
  standalone: true,
  imports: [AsyncPipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (months$ | async; as months) {
      <p class="warranty">保証 {{ months }} か月</p>
    }
  `,
})
export class WarrantyComponent {
  private currentProduct = inject(CurrentProductService);
  months$ = this.currentProduct
    .getProduct()
    .pipe(map((p) => (p as { warrantyMonths?: number } | null)?.warrantyMonths ?? 0));
}
