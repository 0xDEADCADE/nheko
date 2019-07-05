/*
 * nheko Copyright (C) 2017  Konstantinos Sideris <siderisk@auth.gr>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <QBrush>
#include <QDesktopServices>
#include <QFileDialog>
#include <QFileInfo>
#include <QPainter>
#include <QPixmap>
#include <QUuid>
#include <QtGlobal>

#include "Config.h"
#include "ImageItem.h"
#include "Logging.h"
#include "MatrixClient.h"
#include "Utils.h"
#include "dialogs/ImageOverlay.h"

void
ImageItem::downloadMedia(const QUrl &url)
{
        auto proxy = std::make_shared<MediaProxy>();
        connect(proxy.get(), &MediaProxy::imageDownloaded, this, &ImageItem::setImage);

        http::client()->download(url.toString().toStdString(),
                                 [proxy = std::move(proxy), url](const std::string &data,
                                                                 const std::string &,
                                                                 const std::string &,
                                                                 mtx::http::RequestErr err) {
                                         if (err) {
                                                 nhlog::net()->warn(
                                                   "failed to retrieve image {}: {} {}",
                                                   url.toString().toStdString(),
                                                   err->matrix_error.error,
                                                   static_cast<int>(err->status_code));
                                                 return;
                                         }

                                         QPixmap img;
                                         img.loadFromData(QByteArray(data.data(), data.size()));

                                         emit proxy->imageDownloaded(img);
                                 });
}

void
ImageItem::saveImage(const QString &filename, const QByteArray &data)
{
        try {
                QFile file(filename);

                if (!file.open(QIODevice::WriteOnly))
                        return;

                file.write(data);
                file.close();
        } catch (const std::exception &e) {
                nhlog::ui()->warn("Error while saving file to: {}", e.what());
        }
}

void
ImageItem::init()
{
        setMouseTracking(true);
        setCursor(Qt::PointingHandCursor);
        setAttribute(Qt::WA_Hover, true);

        downloadMedia(url_);
}

ImageItem::ImageItem(const mtx::events::RoomEvent<mtx::events::msg::Image> &event, QWidget *parent)
  : QWidget(parent)
  , event_{event}
{
        url_  = QString::fromStdString(event.content.url);
        text_ = QString::fromStdString(event.content.body);

        init();
}

ImageItem::ImageItem(const QString &url, const QString &filename, uint64_t size, QWidget *parent)
  : QWidget(parent)
  , url_{url}
  , text_{filename}
{
        Q_UNUSED(size);
        init();
}

void
ImageItem::openUrl()
{
        if (url_.toString().isEmpty())
                return;

        auto urlToOpen = utils::mxcToHttp(
          url_, QString::fromStdString(http::client()->server()), http::client()->port());

        if (!QDesktopServices::openUrl(urlToOpen))
                nhlog::ui()->warn("could not open url: {}", urlToOpen.toStdString());
}

QSize
ImageItem::sizeHint() const
{
        if (image_.isNull())
                return QSize(max_width_, bottom_height_);

        return QSize(width_, height_);
}

void
ImageItem::setImage(const QPixmap &image)
{
        image_        = image;
        scaled_image_ = utils::scaleDown(max_width_, max_height_, image_);

        width_  = scaled_image_.width();
        height_ = scaled_image_.height();

        setFixedSize(width_, height_);
        update();
}

void
ImageItem::mousePressEvent(QMouseEvent *event)
{
        if (!isInteractive_) {
                event->accept();
                return;
        }

        if (event->button() != Qt::LeftButton)
                return;

        if (image_.isNull()) {
                openUrl();
                return;
        }

        if (textRegion_.contains(event->pos())) {
                openUrl();
        } else {
                auto imgDialog = new dialogs::ImageOverlay(image_);
                imgDialog->show();
                connect(imgDialog, &dialogs::ImageOverlay::saving, this, &ImageItem::saveAs);
        }
}

void
ImageItem::resizeEvent(QResizeEvent *event)
{
        if (!image_)
                return QWidget::resizeEvent(event);

        scaled_image_ = utils::scaleDown(max_width_, max_height_, image_);

        width_  = scaled_image_.width();
        height_ = scaled_image_.height();

        setFixedSize(width_, height_);
}

void
ImageItem::paintEvent(QPaintEvent *event)
{
        Q_UNUSED(event);

        QPainter painter(this);
        painter.setRenderHint(QPainter::Antialiasing);

        QFont font;

        QFontMetrics metrics(font);
        const int fontHeight = metrics.height() + metrics.ascent();

        if (image_.isNull()) {
                QString elidedText = metrics.elidedText(text_, Qt::ElideRight, max_width_ - 10);
#if QT_VERSION < QT_VERSION_CHECK(5, 11, 0)
                setFixedSize(metrics.width(elidedText), fontHeight);
#else
                setFixedSize(metrics.horizontalAdvance(elidedText), fontHeight);
#endif
                painter.setFont(font);
                painter.setPen(QPen(QColor(66, 133, 244)));
                painter.drawText(QPoint(0, fontHeight / 2), elidedText);

                return;
        }

        imageRegion_ = QRectF(0, 0, width_, height_);

        QPainterPath path;
        path.addRoundedRect(imageRegion_, 5, 5);

        painter.setPen(Qt::NoPen);
        painter.fillPath(path, scaled_image_);
        painter.drawPath(path);

        // Bottom text section
        if (isInteractive_ && underMouse()) {
                const int textBoxHeight = fontHeight / 2 + 6;

                textRegion_ = QRectF(0, height_ - textBoxHeight, width_, textBoxHeight);

                QPainterPath textPath;
                textPath.addRoundedRect(textRegion_, 0, 0);

                painter.fillPath(textPath, QColor(40, 40, 40, 140));

                QString elidedText = metrics.elidedText(text_, Qt::ElideRight, width_ - 10);

                font.setWeight(QFont::Medium);
                painter.setFont(font);
                painter.setPen(QPen(QColor(Qt::white)));

                textRegion_.adjust(5, 0, 5, 0);
                painter.drawText(textRegion_, Qt::AlignVCenter, elidedText);
        }
}

void
ImageItem::saveAs()
{
        auto filename = QFileDialog::getSaveFileName(this, tr("Save image"), text_);

        if (filename.isEmpty())
                return;

        const auto url = url_.toString().toStdString();

        auto proxy = std::make_shared<MediaProxy>();
        connect(proxy.get(), &MediaProxy::imageSaved, this, &ImageItem::saveImage);

        http::client()->download(
          url,
          [proxy = std::move(proxy), filename, url](const std::string &data,
                                                    const std::string &,
                                                    const std::string &,
                                                    mtx::http::RequestErr err) {
                  if (err) {
                          nhlog::net()->warn("failed to retrieve image {}: {} {}",
                                             url,
                                             err->matrix_error.error,
                                             static_cast<int>(err->status_code));
                          return;
                  }

                  emit proxy->imageSaved(filename, QByteArray(data.data(), data.size()));
          });
}
